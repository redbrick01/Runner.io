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
