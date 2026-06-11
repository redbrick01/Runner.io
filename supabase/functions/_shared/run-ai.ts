import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.26.0";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export type JsonRecord = Record<string, unknown>;

export type SupabaseClient = any;

type AuthenticatedClients = {
  env: { supabaseUrl: string; anonKey: string; serviceRoleKey: string };
  authHeader: string;
  adminClient: SupabaseClient;
  user: { id: string };
};

export type RunRow = {
  id: number;
  started_at: string;
  ended_at: string;
  duration: number;
  distance: number;
  created_at: string;
  user_id: string;
  point: number;
  avg_pace: number | null;
  calories: number | null;
  area: number | null;
  path_geom: string | null;
  loop_geom: string | null;
};

export type RunSplitRow = {
  run_id: number;
  split_index: number;
  distance_m: number;
  duration_s: number;
  avg_pace_s_per_km: number | null;
  avg_speed_mps: number | null;
  ascent_m: number | null;
  calories: number | null;
  path_geom: string | null;
};

export type RunSummary = {
  run: RunRow;
  splits: RunSplitRow[];
  summaryText: string;
  numericFeatures: JsonRecord;
  totalAscentM: number;
  paceVariance: number;
};

export type SegmentFeature = {
  userId: string;
  runId: number;
  splitIndex: number;
  summaryText: string;
  featureJson: JsonRecord;
  splitPaceSecondsPerKm: number;
  avgPaceUntilSplitSecondsPerKm: number;
  paceDeltaPrevSeconds: number | null;
  paceDeltaAvgSeconds: number;
  distanceMeters: number;
  durationSeconds: number;
  ascentMeters: number;
  nextSplitPaceSecondsPerKm: number | null;
  nextPaceDeltaSeconds: number | null;
  nextOutcome: string | null;
};

export type LiveSegmentSnapshot = {
  runSessionId: string | null;
  completedKm: number;
  splitIndex: number;
  elapsedSeconds: number;
  distanceMeters: number;
  splitDurationSeconds: number;
  splitPaceSeconds: number;
  averagePaceSeconds: number;
  previousSplitPaces: number[];
  currentSpeedKmh: number | null;
  ascentThisSplitMeters: number;
  pauseCount: number;
  goalPaceSeconds: number | null;
  recentCoachingCategories: string[];
  excludeRunId: number | null;
  featureJson: JsonRecord;
  summaryText: string;
};

export function json(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
      ...(init.headers ?? {}),
    },
  });
}

export function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function toFiniteNumber(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "string" && value.trim() === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function getEnv() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return null;
  }
  return { supabaseUrl, anonKey, serviceRoleKey };
}

export async function getAuthenticatedClients(
  req: Request,
): Promise<AuthenticatedClients | { error: Response }> {
  const env = getEnv();
  if (!env) {
    return {
      error: json(
        { error: "Missing required Supabase environment variables" },
        { status: 500 },
      ),
    };
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return {
      error: json({ error: "Missing Authorization header" }, { status: 401 }),
    };
  }

  const adminClient = createClient(env.supabaseUrl, env.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const token = authHeader.replace(/^Bearer\s+/i, "");
  const {
    data: { user },
    error: userError,
  } = await adminClient.auth.getUser(token);

  if (userError || !user) {
    return {
      error: json(
        { error: userError?.message ?? "Unauthorized" },
        { status: 401 },
      ),
    };
  }

  return { env, authHeader, adminClient, user };
}

export async function fetchRunSummary(
  adminClient: SupabaseClient,
  userId: string,
  runId: number,
): Promise<RunSummary | null> {
  const { data: runData, error: runError } = await adminClient
    .from("runs")
    .select(
      "id, started_at, ended_at, duration, distance, created_at, user_id, point, avg_pace, calories, area, path_geom, loop_geom",
    )
    .eq("id", runId)
    .eq("user_id", userId)
    .maybeSingle();

  if (runError) {
    throw new Error(`Failed to fetch run: ${runError.message}`);
  }
  if (!runData) return null;

  const { data: splitData, error: splitError } = await adminClient
    .from("run_splits")
    .select(
      "run_id, split_index, distance_m, duration_s, avg_pace_s_per_km, avg_speed_mps, ascent_m, calories, path_geom",
    )
    .eq("run_id", runId)
    .order("split_index", { ascending: true });

  if (splitError) {
    throw new Error(`Failed to fetch run splits: ${splitError.message}`);
  }

  return buildRunSummary(runData as RunRow, (splitData ?? []) as RunSplitRow[]);
}

export function buildRunSummary(
  run: RunRow,
  splits: RunSplitRow[],
): RunSummary {
  const distanceKm = safeNumber(run.distance) / 1000;
  const durationMin = safeNumber(run.duration) / 60;
  const avgPace = safeNumber(run.avg_pace);
  const avgSpeedMps = run.duration > 0 ? run.distance / run.duration : 0;
  const totalAscentM = splits.reduce(
    (sum, split) => sum + Math.max(0, safeNumber(split.ascent_m)),
    0,
  );
  const paceSeries = splits
    .map((split) => safeNumber(split.avg_pace_s_per_km))
    .filter((value) => value > 0);
  const paceVariance = variance(paceSeries);
  const positiveSplitScore = buildPositiveSplitScore(paceSeries);
  const started = new Date(run.started_at);
  const weekday = Number.isNaN(started.getTime())
    ? "unknown"
    : started.getDay();
  const hourOfDay = Number.isNaN(started.getTime())
    ? "unknown"
    : started.getHours();

  const numericFeatures: JsonRecord = {
    distance_km: round(distanceKm, 3),
    duration_min: round(durationMin, 2),
    avg_pace_s_per_km: round(avgPace, 1),
    avg_speed_mps: round(avgSpeedMps, 3),
    calories: round(safeNumber(run.calories), 1),
    total_ascent_m: round(totalAscentM, 1),
    area_m2: round(safeNumber(run.area), 1),
    split_count: splits.length,
    pace_variance: round(paceVariance, 3),
    positive_split_score: round(positiveSplitScore, 3),
  };

  const paceText = paceSeries.length > 0
    ? paceSeries.map((v) => Math.round(v)).join(",")
    : "none";
  const ascentText = splits.length > 0
    ? splits.map((split) => Math.round(safeNumber(split.ascent_m))).join(",")
    : "none";

  const summaryText = [
    `distance_km=${round(distanceKm, 3)}`,
    `duration_s=${Math.round(safeNumber(run.duration))}`,
    `avg_pace_s_per_km=${round(avgPace, 1)}`,
    `avg_speed_mps=${round(avgSpeedMps, 3)}`,
    `calories=${round(safeNumber(run.calories), 1)}`,
    `point=${round(safeNumber(run.point), 1)}`,
    `area_m2=${round(safeNumber(run.area), 1)}`,
    `total_ascent_m=${round(totalAscentM, 1)}`,
    `split_count=${splits.length}`,
    `split_pace_series=${paceText}`,
    `split_ascent_series=${ascentText}`,
    `weekday=${weekday}`,
    `hour_of_day=${hourOfDay}`,
  ].join(" ");

  return {
    run,
    splits,
    summaryText,
    numericFeatures,
    totalAscentM,
    paceVariance,
  };
}

export async function upsertRunFeatures(
  adminClient: SupabaseClient,
  summary: RunSummary,
  embedding: number[] | null,
  status: "completed" | "failed" | "pending",
  errorMessage: string | null = null,
) {
  const run = summary.run;
  const featureRow = {
    run_id: run.id,
    user_id: run.user_id,
    embedding: embedding ? JSON.stringify(embedding) : null,
    numeric_features: summary.numericFeatures,
    summary_text: summary.summaryText,
    total_ascent_m: summary.totalAscentM,
    pace_variance: summary.paceVariance,
    route_centroid: null,
    route_bbox: null,
    embedding_model: "gte-small",
    embedding_status: status,
    error_message: errorMessage,
    embedded_at: status === "completed" ? new Date().toISOString() : null,
  };

  const { error } = await adminClient
    .from("run_ai_features")
    .upsert(featureRow, { onConflict: "run_id" });
  if (error) {
    throw new Error(`Failed to upsert run_ai_features: ${error.message}`);
  }
}

export function buildSegmentFeatures(summary: RunSummary): SegmentFeature[] {
  const result: SegmentFeature[] = [];
  let cumulativeDuration = 0;
  let cumulativeDistance = 0;
  let previousPace: number | null = null;

  for (let index = 0; index < summary.splits.length; index++) {
    const split = summary.splits[index];
    const nextSplit = summary.splits[index + 1] ?? null;
    const splitDistance = Math.max(0, safeNumber(split.distance_m));
    const splitDuration = Math.max(0, safeNumber(split.duration_s));
    const splitPace = normalizedPace(
      split.avg_pace_s_per_km,
      splitDuration,
      splitDistance,
    );
    cumulativeDuration += splitDuration;
    cumulativeDistance += splitDistance;
    const averagePace = normalizedPace(
      null,
      cumulativeDuration,
      cumulativeDistance,
    );
    const paceDeltaPrev = previousPace === null
      ? null
      : splitPace - previousPace;
    const paceDeltaAvg = splitPace - averagePace;
    const ascent = safeNumber(split.ascent_m);
    const nextPace = nextSplit
      ? normalizedPace(
        nextSplit.avg_pace_s_per_km,
        safeNumber(nextSplit.duration_s),
        safeNumber(nextSplit.distance_m),
      )
      : null;
    const nextDelta = nextPace === null ? null : nextPace - splitPace;
    const nextOutcome = buildNextOutcome(nextDelta);
    const phase = buildRunPhase(split.split_index, summary.splits.length);

    const featureJson: JsonRecord = {
      completed_km: split.split_index,
      phase,
      split_pace_s_per_km: round(splitPace, 1),
      avg_pace_until_split_s_per_km: round(averagePace, 1),
      pace_delta_prev_s: paceDeltaPrev === null
        ? null
        : round(paceDeltaPrev, 1),
      pace_delta_avg_s: round(paceDeltaAvg, 1),
      trend: buildTrend(paceDeltaPrev),
      ascent_m: round(ascent, 1),
      pause_count: 0,
      goal_context: "none",
      next_outcome: nextOutcome,
    };

    const summaryText = [
      `split_index=${split.split_index}`,
      `phase=${phase}`,
      `split_pace_s_per_km=${round(splitPace, 1)}`,
      `avg_pace_until_split_s_per_km=${round(averagePace, 1)}`,
      `pace_delta_prev_s=${
        paceDeltaPrev === null ? "none" : round(paceDeltaPrev, 1)
      }`,
      `pace_delta_avg_s=${round(paceDeltaAvg, 1)}`,
      `trend=${buildTrend(paceDeltaPrev)}`,
      `ascent_m=${round(ascent, 1)}`,
      `next_outcome=${nextOutcome ?? "none"}`,
    ].join(" ");

    result.push({
      userId: summary.run.user_id,
      runId: summary.run.id,
      splitIndex: split.split_index,
      summaryText,
      featureJson,
      splitPaceSecondsPerKm: splitPace,
      avgPaceUntilSplitSecondsPerKm: averagePace,
      paceDeltaPrevSeconds: paceDeltaPrev,
      paceDeltaAvgSeconds: paceDeltaAvg,
      distanceMeters: splitDistance,
      durationSeconds: splitDuration,
      ascentMeters: ascent,
      nextSplitPaceSecondsPerKm: nextPace,
      nextPaceDeltaSeconds: nextDelta,
      nextOutcome,
    });

    previousPace = splitPace;
  }

  return result;
}

export async function upsertSegmentFeature(
  adminClient: SupabaseClient,
  feature: SegmentFeature,
  embedding: number[] | null,
  status: "completed" | "failed" | "pending",
  errorMessage: string | null = null,
) {
  const row = {
    user_id: feature.userId,
    run_id: feature.runId,
    split_index: feature.splitIndex,
    embedding: embedding ? JSON.stringify(embedding) : null,
    feature_json: feature.featureJson,
    summary_text: feature.summaryText,
    split_pace_s_per_km: round(feature.splitPaceSecondsPerKm, 2),
    avg_pace_until_split_s_per_km: round(
      feature.avgPaceUntilSplitSecondsPerKm,
      2,
    ),
    pace_delta_prev_s: feature.paceDeltaPrevSeconds === null
      ? null
      : round(feature.paceDeltaPrevSeconds, 2),
    pace_delta_avg_s: round(feature.paceDeltaAvgSeconds, 2),
    distance_m: round(feature.distanceMeters, 2),
    duration_s: round(feature.durationSeconds, 2),
    ascent_m: round(feature.ascentMeters, 2),
    next_split_pace_s_per_km: feature.nextSplitPaceSecondsPerKm === null
      ? null
      : round(feature.nextSplitPaceSecondsPerKm, 2),
    next_pace_delta_s: feature.nextPaceDeltaSeconds === null
      ? null
      : round(feature.nextPaceDeltaSeconds, 2),
    next_outcome: feature.nextOutcome,
    embedding_model: "gte-small",
    embedding_status: status,
    error_message: errorMessage,
    embedded_at: status === "completed" ? new Date().toISOString() : null,
  };

  const { error } = await adminClient
    .from("run_segment_ai_features")
    .upsert(row, { onConflict: "run_id,split_index" });
  if (error) {
    throw new Error(
      `Failed to upsert run_segment_ai_features: ${error.message}`,
    );
  }
}

export function buildLiveSegmentSnapshot(
  payload: JsonRecord,
): LiveSegmentSnapshot {
  const completedKm = Math.max(
    1,
    Math.floor(toFiniteNumber(payload.completed_km) ?? 0),
  );
  const elapsedSeconds = Math.max(
    0,
    toFiniteNumber(payload.elapsed_seconds) ?? 0,
  );
  const distanceMeters = Math.max(
    0,
    toFiniteNumber(payload.distance_meters) ?? 0,
  );
  const splitDurationSeconds = Math.max(
    0,
    toFiniteNumber(payload.split_duration_seconds) ??
      toFiniteNumber(payload.split_pace_seconds) ??
      0,
  );
  const splitPaceSeconds = Math.max(
    0,
    toFiniteNumber(payload.split_pace_seconds) ?? splitDurationSeconds,
  );
  const averagePaceSeconds = Math.max(
    0,
    toFiniteNumber(payload.average_pace_seconds) ??
      normalizedPace(null, elapsedSeconds, distanceMeters),
  );
  const previousSplitPaces = Array.isArray(payload.previous_split_paces)
    ? payload.previous_split_paces
      .map((value) => toFiniteNumber(value))
      .filter((value): value is number => value !== null && value > 0)
      .slice(-6)
    : [];
  const previousPace = previousSplitPaces.length > 0
    ? previousSplitPaces[previousSplitPaces.length - 1]
    : null;
  const paceDeltaPrev = previousPace === null
    ? null
    : splitPaceSeconds - previousPace;
  const paceDeltaAvg = splitPaceSeconds - averagePaceSeconds;
  const ascentThisSplitMeters = toFiniteNumber(payload.ascent_this_split_m) ??
    0;
  const pauseCount = Math.max(
    0,
    Math.floor(toFiniteNumber(payload.pause_count) ?? 0),
  );
  const goalPaceSeconds = toFiniteNumber(payload.goal_pace_seconds);
  const excludeRunId = toFiniteNumber(payload.exclude_run_id);
  const currentSpeedKmh = toFiniteNumber(payload.current_speed_kmh);
  const recentCoachingCategories =
    Array.isArray(payload.recent_coaching_categories)
      ? payload.recent_coaching_categories
        .map((value) => String(value))
        .filter((value) => value.trim().length > 0)
        .slice(-4)
      : [];
  const phase = buildLivePhase(completedKm);
  const trend = buildTrend(paceDeltaPrev);
  const featureJson: JsonRecord = {
    completed_km: completedKm,
    phase,
    split_pace_s_per_km: round(splitPaceSeconds, 1),
    avg_pace_until_split_s_per_km: round(averagePaceSeconds, 1),
    pace_delta_prev_s: paceDeltaPrev === null ? null : round(paceDeltaPrev, 1),
    pace_delta_avg_s: round(paceDeltaAvg, 1),
    trend,
    ascent_m: round(ascentThisSplitMeters, 1),
    pause_count: pauseCount,
    goal_context: goalPaceSeconds && goalPaceSeconds > 0
      ? `target_pace_s_per_km=${round(goalPaceSeconds, 1)}`
      : "none",
  };
  const summaryText = [
    `split_index=${completedKm}`,
    `phase=${phase}`,
    `split_pace_s_per_km=${round(splitPaceSeconds, 1)}`,
    `avg_pace_until_split_s_per_km=${round(averagePaceSeconds, 1)}`,
    `pace_delta_prev_s=${
      paceDeltaPrev === null ? "none" : round(paceDeltaPrev, 1)
    }`,
    `pace_delta_avg_s=${round(paceDeltaAvg, 1)}`,
    `trend=${trend}`,
    `ascent_m=${round(ascentThisSplitMeters, 1)}`,
    `pause_count=${pauseCount}`,
    `goal_pace_s_per_km=${goalPaceSeconds ?? "none"}`,
  ].join(" ");

  return {
    runSessionId: typeof payload.run_session_id === "string"
      ? payload.run_session_id
      : null,
    completedKm,
    splitIndex: completedKm,
    elapsedSeconds,
    distanceMeters,
    splitDurationSeconds,
    splitPaceSeconds,
    averagePaceSeconds,
    previousSplitPaces,
    currentSpeedKmh,
    ascentThisSplitMeters,
    pauseCount,
    goalPaceSeconds,
    recentCoachingCategories,
    excludeRunId: excludeRunId === null || excludeRunId <= 0
      ? null
      : Math.floor(excludeRunId),
    featureJson,
    summaryText,
  };
}

export async function updateFeatureGeometry(
  adminClient: SupabaseClient,
  runId: number,
) {
  const { error } = await adminClient.rpc("set_run_ai_feature_geometry", {
    p_run_id: runId,
  });
  if (error) {
    console.warn("Failed to update AI feature geometry", error.message);
  }
}

export function buildFallbackReport(
  summary: RunSummary,
  similarRuns: JsonRecord[],
  status: "completed" | "insufficient_data" | "failed" = "completed",
  errorMessage: string | null = null,
) {
  const distanceKm = safeNumber(summary.run.distance) / 1000;
  const pace = safeNumber(summary.run.avg_pace);
  const similarCount = similarRuns.length;

  return {
    run_id: summary.run.id,
    user_id: summary.run.user_id,
    similar_run_ids: similarRuns.map((item) => Number(item.run_id)).filter(
      Number.isFinite,
    ),
    model: Deno.env.get("OPENAI_MODEL") ?? "gpt-5.4-mini",
    summary: similarCount >= 3
      ? `오늘 러닝은 최근 비슷한 ${similarCount}개 기록과 비교해 ${
        distanceKm.toFixed(2)
      }km 구간의 흐름을 확인할 수 있어요.`
      : "비교할 과거 러닝이 아직 부족해요. 기록이 조금 더 쌓이면 더 정교한 비교 리포트를 만들 수 있어요.",
    improvements: similarCount >= 3
      ? [
        "초반과 후반 페이스 차이를 줄이면 기록 안정성이 좋아져요.",
        "비슷한 거리의 러닝을 같은 강도로 반복해 기준 기록을 만들어 보세요.",
      ]
      : [
        "비슷한 거리의 러닝을 3회 이상 저장하면 개선점을 더 정확히 볼 수 있어요.",
      ],
    next_goal: {
      type: "pace",
      label: pace > 0
        ? `다음 러닝 평균 페이스 ${Math.max(1, Math.round(pace - 5))}초/km 도전`
        : "다음 러닝에서 같은 거리를 일정한 페이스로 완주",
      target_pace_s_per_km: pace > 0 ? Math.max(1, Math.round(pace - 5)) : null,
    },
    coaching_message:
      "오늘의 기록은 다음 러닝을 더 잘 설계할 수 있는 좋은 기준점이에요.",
    comparison: {
      similar_run_count: similarCount,
      generated_by: errorMessage ? "fallback_after_llm_error" : "fallback",
    },
    status,
    error_message: errorMessage,
  };
}

export async function upsertRunReport(
  adminClient: SupabaseClient,
  report: JsonRecord,
) {
  const { error } = await adminClient
    .from("run_ai_reports")
    .upsert(report, { onConflict: "run_id" });
  if (error) {
    throw new Error(`Failed to upsert run_ai_reports: ${error.message}`);
  }
}

export async function generateEmbedding(input: string): Promise<number[]> {
  const edgeSupabase = (globalThis as { Supabase?: any }).Supabase;
  if (!edgeSupabase?.ai?.Session) {
    throw new Error("Supabase AI inference API is not available");
  }
  const session = new edgeSupabase.ai.Session("gte-small");
  const embedding = await session.run(input, {
    mean_pool: true,
    normalize: true,
  });
  if (!Array.isArray(embedding)) {
    throw new Error("Embedding model returned an invalid result");
  }
  return embedding.map((value) => Number(value));
}

export async function callOpenAiReport(
  summary: RunSummary,
  similarRuns: JsonRecord[],
): Promise<JsonRecord> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is not configured");
  }
  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-5.4-mini";
  const prompt = {
    task:
      "Compare the current running record with similar past runs and return Korean coaching JSON.",
    rules: [
      "Return only valid JSON.",
      "Do not include medical diagnosis or injury certainty.",
      "Keep Korean text concise, friendly, and specific.",
      "Fields: summary string, improvements string[], next_goal object, coaching_message string, comparison object.",
    ],
    current_run: {
      run_id: summary.run.id,
      started_at: summary.run.started_at,
      numeric_features: summary.numericFeatures,
      summary_text: summary.summaryText,
    },
    similar_runs: similarRuns,
  };

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "system",
          content:
            "You are a Korean running coach for a mobile running app. Return compact JSON only.",
        },
        {
          role: "user",
          content: JSON.stringify(prompt),
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "run_ai_report",
          schema: {
            type: "object",
            additionalProperties: false,
            required: [
              "summary",
              "improvements",
              "next_goal",
              "coaching_message",
              "comparison",
            ],
            properties: {
              summary: { type: "string" },
              improvements: {
                type: "array",
                items: { type: "string" },
                minItems: 1,
                maxItems: 3,
              },
              next_goal: {
                type: "object",
                additionalProperties: false,
                required: [
                  "type",
                  "label",
                  "target_pace_s_per_km",
                  "target_distance_km",
                ],
                properties: {
                  type: { type: "string" },
                  label: { type: "string" },
                  target_pace_s_per_km: {
                    type: ["number", "null"],
                  },
                  target_distance_km: {
                    type: ["number", "null"],
                  },
                },
              },
              coaching_message: { type: "string" },
              comparison: {
                type: "object",
                additionalProperties: false,
                required: [
                  "similar_run_count",
                  "pace_delta_s_per_km",
                  "distance_delta_km",
                  "note",
                ],
                properties: {
                  similar_run_count: { type: "number" },
                  pace_delta_s_per_km: {
                    type: ["number", "null"],
                  },
                  distance_delta_km: {
                    type: ["number", "null"],
                  },
                  note: { type: "string" },
                },
              },
            },
          },
          strict: true,
        },
      },
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI request failed: ${response.status} ${body}`);
  }

  const decoded = await response.json();
  const text = extractResponseText(decoded);
  const parsed = JSON.parse(text);
  if (!isRecord(parsed)) {
    throw new Error("OpenAI report is not a JSON object");
  }
  return parsed;
}

export function buildFallbackLiveCoaching(
  snapshot: LiveSegmentSnapshot,
  similarSegments: JsonRecord[] = [],
  fallbackUsed = true,
) {
  const message = similarSegments.length >= 3
    ? buildRuleBasedLiveMessage(snapshot, "similar")
    : buildRuleBasedLiveMessage(snapshot, "insufficient");
  return {
    status: similarSegments.length >= 3 ? "completed" : "insufficient_data",
    coaching_message: message,
    coaching_category: categorizeLiveSnapshot(snapshot),
    similar_segment_count: similarSegments.length,
    fallback_used: fallbackUsed,
  };
}

export async function callOpenAiLiveCoaching(
  snapshot: LiveSegmentSnapshot,
  similarSegments: JsonRecord[],
): Promise<JsonRecord> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is not configured");
  }
  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-5.4-mini";
  const prompt = {
    task:
      "Return one short Korean live running voice coaching sentence based on the current split and similar past split outcomes.",
    rules: [
      "Return only valid JSON.",
      "coaching_message must be Korean, 20 to 60 characters, one sentence.",
      "Suggest at most one action.",
      "Use at most two numbers.",
      "Do not include medical diagnosis, injury certainty, or harsh pressure.",
      "Avoid repeating recent_coaching_categories if possible.",
    ],
    current_segment: {
      completed_km: snapshot.completedKm,
      elapsed_seconds: snapshot.elapsedSeconds,
      distance_meters: snapshot.distanceMeters,
      split_pace_s_per_km: snapshot.splitPaceSeconds,
      average_pace_s_per_km: snapshot.averagePaceSeconds,
      previous_split_paces: snapshot.previousSplitPaces,
      current_speed_kmh: snapshot.currentSpeedKmh,
      ascent_this_split_m: snapshot.ascentThisSplitMeters,
      pause_count: snapshot.pauseCount,
      goal_pace_s_per_km: snapshot.goalPaceSeconds,
      summary_text: snapshot.summaryText,
    },
    similar_segments: similarSegments.slice(0, 5).map((item) => ({
      split_index: item.split_index,
      summary_text: item.summary_text,
      split_pace_s_per_km: item.split_pace_s_per_km,
      pace_delta_prev_s: item.pace_delta_prev_s,
      next_split_pace_s_per_km: item.next_split_pace_s_per_km,
      next_pace_delta_s: item.next_pace_delta_s,
      next_outcome: item.next_outcome,
      similarity_score: item.similarity_score,
    })),
    recent_coaching_categories: snapshot.recentCoachingCategories,
  };

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "system",
          content:
            "You are a Korean running coach speaking into a runner's ear during a run. Return compact JSON only.",
        },
        {
          role: "user",
          content: JSON.stringify(prompt),
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "live_run_coaching",
          schema: {
            type: "object",
            additionalProperties: false,
            required: [
              "coaching_message",
              "coaching_category",
            ],
            properties: {
              coaching_message: { type: "string" },
              coaching_category: { type: "string" },
            },
          },
          strict: true,
        },
      },
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI request failed: ${response.status} ${body}`);
  }

  const decoded = await response.json();
  const parsed = JSON.parse(extractResponseText(decoded));
  if (!isRecord(parsed)) {
    throw new Error("OpenAI live coaching is not a JSON object");
  }

  const message = normalizeLiveCoachingMessage(
    String(parsed.coaching_message ?? ""),
    snapshot,
  );
  return {
    status: "completed",
    coaching_message: message,
    coaching_category: String(
      parsed.coaching_category ?? categorizeLiveSnapshot(snapshot),
    ),
    similar_segment_count: similarSegments.length,
    fallback_used: false,
  };
}

export function normalizeReport(
  summary: RunSummary,
  similarRuns: JsonRecord[],
  llmReport: JsonRecord,
) {
  return {
    run_id: summary.run.id,
    user_id: summary.run.user_id,
    similar_run_ids: similarRuns.map((item) => Number(item.run_id)).filter(
      Number.isFinite,
    ),
    model: Deno.env.get("OPENAI_MODEL") ?? "gpt-5.4-mini",
    summary: String(llmReport.summary ?? ""),
    improvements: Array.isArray(llmReport.improvements)
      ? llmReport.improvements.slice(0, 3).map((item) => String(item))
      : [],
    next_goal: isRecord(llmReport.next_goal) ? llmReport.next_goal : {},
    coaching_message: String(llmReport.coaching_message ?? ""),
    comparison: isRecord(llmReport.comparison)
      ? {
        ...llmReport.comparison,
        similar_run_count: similarRuns.length,
      }
      : { similar_run_count: similarRuns.length },
    status: "completed",
    error_message: null,
  };
}

function normalizeLiveCoachingMessage(
  message: string,
  snapshot: LiveSegmentSnapshot,
): string {
  const normalized = message.replace(/\s+/g, " ").trim();
  if (normalized.length >= 8 && normalized.length <= 80) {
    return normalized;
  }
  return buildRuleBasedLiveMessage(snapshot, "similar");
}

function extractResponseText(decoded: unknown): string {
  if (!isRecord(decoded)) {
    throw new Error("OpenAI response is not an object");
  }
  if (typeof decoded.output_text === "string") {
    return decoded.output_text;
  }
  const output = decoded.output;
  if (Array.isArray(output)) {
    for (const item of output) {
      if (!isRecord(item)) continue;
      const content = item.content;
      if (!Array.isArray(content)) continue;
      for (const contentItem of content) {
        if (isRecord(contentItem) && typeof contentItem.text === "string") {
          return contentItem.text;
        }
      }
    }
  }
  throw new Error("OpenAI response did not include output text");
}

function safeNumber(value: unknown): number {
  return toFiniteNumber(value) ?? 0;
}

function round(value: number, digits: number): number {
  const factor = Math.pow(10, digits);
  return Math.round(value * factor) / factor;
}

function variance(values: number[]): number {
  if (values.length <= 1) return 0;
  const mean = values.reduce((sum, value) => sum + value, 0) / values.length;
  return values.reduce((sum, value) => sum + Math.pow(value - mean, 2), 0) /
    values.length;
}

function buildPositiveSplitScore(paces: number[]): number {
  if (paces.length < 2) return 0;
  const firstHalf = paces.slice(0, Math.ceil(paces.length / 2));
  const secondHalf = paces.slice(Math.floor(paces.length / 2));
  const firstAvg = firstHalf.reduce((sum, value) => sum + value, 0) /
    firstHalf.length;
  const secondAvg = secondHalf.reduce((sum, value) => sum + value, 0) /
    secondHalf.length;
  return firstAvg - secondAvg;
}

function normalizedPace(
  rawPace: unknown,
  durationSeconds: number,
  distanceMeters: number,
): number {
  const pace = toFiniteNumber(rawPace);
  if (pace !== null && pace > 0) return pace;
  if (durationSeconds > 0 && distanceMeters > 0) {
    return durationSeconds / (distanceMeters / 1000);
  }
  return 0;
}

function buildRunPhase(splitIndex: number, splitCount: number): string {
  if (splitCount <= 1) return "single";
  const ratio = splitIndex / splitCount;
  if (ratio <= 0.34) return "early";
  if (ratio <= 0.67) return "middle";
  return "late";
}

function buildLivePhase(completedKm: number): string {
  if (completedKm <= 2) return "early";
  if (completedKm <= 6) return "middle";
  return "late";
}

function buildTrend(delta: number | null): string {
  if (delta === null) return "unknown";
  if (delta >= 15) return "fading";
  if (delta >= 5) return "slightly_fading";
  if (delta <= -15) return "surging";
  if (delta <= -5) return "slightly_faster";
  return "steady";
}

function buildNextOutcome(nextDelta: number | null): string | null {
  if (nextDelta === null) return null;
  if (nextDelta >= 15) return "next_split_slowed";
  if (nextDelta >= 5) return "next_split_slightly_slower";
  if (nextDelta <= -15) return "next_split_faster";
  if (nextDelta <= -5) return "next_split_slightly_faster";
  return "next_split_steady";
}

function categorizeLiveSnapshot(snapshot: LiveSegmentSnapshot): string {
  const delta = toFiniteNumber(snapshot.featureJson.pace_delta_prev_s);
  if (delta !== null && delta >= 10) return "pace_recovery";
  if (delta !== null && delta <= -10) return "pace_control";
  const avgDelta = toFiniteNumber(snapshot.featureJson.pace_delta_avg_s);
  if (avgDelta !== null && avgDelta > 10) return "rhythm";
  return "steady";
}

function buildRuleBasedLiveMessage(
  snapshot: LiveSegmentSnapshot,
  source: "similar" | "insufficient",
): string {
  const category = categorizeLiveSnapshot(snapshot);
  if (source === "insufficient") {
    if (category === "pace_recovery") {
      return "조금 느려졌어요. 다음 구간은 호흡 리듬만 다시 잡아보세요.";
    }
    if (category === "pace_control") {
      return "페이스가 빨라졌어요. 초반 힘을 조금 아껴가세요.";
    }
    return "좋아요. 지금 리듬을 편하게 유지해보세요.";
  }
  if (category === "pace_recovery") {
    return "비슷한 구간에선 더 밀리기 쉬웠어요. 호흡만 안정시켜보세요.";
  }
  if (category === "pace_control") {
    return "비슷한 기록보다 빠릅니다. 힘을 조금 아껴가세요.";
  }
  return "비슷한 기록보다 안정적이에요. 지금 리듬을 이어가세요.";
}
