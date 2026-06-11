import { createClient } from "npm:@supabase/supabase-js@2.26.0";
import {
  buildSegmentFeatures,
  corsHeaders,
  fetchRunSummary,
  generateEmbedding,
  getAuthenticatedClients,
  getEnv,
  json,
  SupabaseClient,
  toFiniteNumber,
  updateFeatureGeometry,
  upsertRunFeatures,
  upsertSegmentFeature,
} from "../_shared/run-ai.ts";

type BackfillClients =
  | { adminClient: SupabaseClient; user: { id: string } }
  | { error: Response };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, { status: 405 });
  }

  const requestUrl = new URL(req.url);
  const limitParam = toFiniteNumber(requestUrl.searchParams.get("limit"));
  const limit = Math.min(Math.max(Math.floor(limitParam ?? 20), 1), 50);
  const scope = requestUrl.searchParams.get("scope") ?? "user";
  const target = requestUrl.searchParams.get("target") ?? "runs";
  const isAdminScope = scope === "all";
  const isSegmentTarget = target === "segments";

  const clientsResult: BackfillClients = isAdminScope
    ? getAdminBackfillClients(req)
    : await getAuthenticatedClients(req);
  if ("error" in clientsResult) return clientsResult.error;
  const clients = clientsResult;

  const runRowsResult = isSegmentTarget
    ? await fetchSegmentBackfillRunRows(
      clients.adminClient,
      isAdminScope ? undefined : clients.user.id,
      limit,
    )
    : await fetchRunBackfillRows(
      clients.adminClient,
      isAdminScope ? undefined : clients.user.id,
      limit,
    );

  if ("error" in runRowsResult) {
    return json(
      {
        error: "Failed to fetch runs for backfill",
        details: runRowsResult.error,
      },
      { status: 500 },
    );
  }
  const runRows = runRowsResult.rows;

  const results: Array<{
    run_id: number;
    user_id?: string;
    status: string;
    error?: string;
  }> = [];
  for (const row of runRows) {
    const typedRow = row as { id?: unknown; user_id?: unknown };
    const runId = toFiniteNumber(typedRow.id);
    const userId = typeof typedRow.user_id === "string"
      ? typedRow.user_id
      : clients.user.id;
    if (runId === null || userId.trim().length === 0) continue;

    try {
      const summary = await fetchRunSummary(
        clients.adminClient,
        userId,
        Math.floor(runId),
      );
      if (!summary) continue;
      if (isSegmentTarget) {
        const segmentFeatures = buildSegmentFeatures(summary);
        for (const feature of segmentFeatures) {
          try {
            const embedding = await generateEmbedding(feature.summaryText);
            await upsertSegmentFeature(
              clients.adminClient,
              feature,
              embedding,
              "completed",
            );
          } catch (segmentError) {
            await upsertSegmentFeature(
              clients.adminClient,
              feature,
              null,
              "failed",
              segmentError instanceof Error
                ? segmentError.message
                : String(segmentError),
            );
          }
        }
      } else {
        const embedding = await generateEmbedding(summary.summaryText);
        await upsertRunFeatures(
          clients.adminClient,
          summary,
          embedding,
          "completed",
        );
        await updateFeatureGeometry(clients.adminClient, summary.run.id);
      }
      results.push({
        run_id: summary.run.id,
        user_id: isAdminScope ? summary.run.user_id : undefined,
        status: isSegmentTarget ? "segments_completed" : "completed",
      });
    } catch (error) {
      results.push({
        run_id: Math.floor(runId),
        user_id: isAdminScope ? userId : undefined,
        status: "failed",
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return json({
    scope: isAdminScope ? "all" : "user",
    target: isSegmentTarget ? "segments" : "runs",
    processed: results.length,
    results,
  });
});

function isValidAdminRequest(req: Request): boolean {
  const expected = Deno.env.get("BACKFILL_ADMIN_SECRET");
  const provided = req.headers.get("x-backfill-admin-secret");
  return Boolean(expected && provided && expected === provided);
}

async function fetchRunBackfillRows(
  adminClient: SupabaseClient,
  userId: string | undefined,
  limit: number,
): Promise<
  { rows: Array<{ id: number; user_id: string }> } | { error: string }
> {
  let query = adminClient
    .from("runs")
    .select("id,user_id")
    .order("started_at", { ascending: true })
    .limit(limit);

  if (userId) {
    query = query
      .eq("user_id", userId)
      .not("id", "in", `(${await existingFeatureRunIds(adminClient, userId)})`);
  } else {
    query = query.not(
      "id",
      "in",
      `(${await existingFeatureRunIds(adminClient)})`,
    );
  }

  const { data, error } = await query;
  if (error) return { error: error.message };
  return {
    rows: (data ?? [])
      .map((row: { id?: unknown; user_id?: unknown }) => ({
        id: toFiniteNumber(row.id),
        user_id: typeof row.user_id === "string" ? row.user_id : "",
      }))
      .filter((row: { id: number | null; user_id: string }) =>
        row.id !== null && row.user_id.trim().length > 0
      )
      .map((row: { id: number | null; user_id: string }) => ({
        id: Math.floor(row.id ?? 0),
        user_id: row.user_id,
      })),
  };
}

async function fetchSegmentBackfillRunRows(
  adminClient: SupabaseClient,
  userId: string | undefined,
  limit: number,
): Promise<
  { rows: Array<{ id: number; user_id: string }> } | { error: string }
> {
  const completedRunIds = new Set(
    (await existingCompletedSegmentRunIds(adminClient, userId))
      .split(",")
      .map((value) => Number(value))
      .filter(Number.isFinite),
  );
  let query = adminClient
    .from("run_splits")
    .select("run_id,runs!inner(user_id,started_at)")
    .order("run_id", { ascending: true })
    .limit(10000);
  if (userId) {
    query = query.eq("runs.user_id", userId);
  }

  const { data, error } = await query;
  if (error) return { error: error.message };

  const rows: Array<{ id: number; user_id: string }> = [];
  const seen = new Set<number>();
  for (const raw of data ?? []) {
    const item = raw as { run_id?: unknown; runs?: unknown };
    const runId = toFiniteNumber(item.run_id);
    const run = item.runs as { user_id?: unknown } | null;
    const rowUserId = typeof run?.user_id === "string" ? run.user_id : "";
    if (runId === null || rowUserId.trim().length === 0) continue;
    const normalizedRunId = Math.floor(runId);
    if (completedRunIds.has(normalizedRunId) || seen.has(normalizedRunId)) {
      continue;
    }
    seen.add(normalizedRunId);
    rows.push({ id: normalizedRunId, user_id: rowUserId });
    if (rows.length >= limit) break;
  }
  return { rows };
}

function getAdminBackfillClients(req: Request): BackfillClients {
  if (!isValidAdminRequest(req)) {
    return { error: json({ error: "Forbidden" }, { status: 403 }) };
  }
  const env = getEnv();
  if (!env) {
    return {
      error: json(
        { error: "Missing required Supabase environment variables" },
        { status: 500 },
      ),
    };
  }
  return {
    adminClient: createClient(env.supabaseUrl, env.serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    }),
    user: { id: "" },
  };
}

async function existingCompletedSegmentRunIds(
  adminClient: SupabaseClient,
  userId?: string,
) {
  let splitQuery = adminClient
    .from("run_splits")
    .select("run_id,runs!inner(user_id)")
    .limit(10000);
  if (userId) {
    splitQuery = splitQuery.eq("runs.user_id", userId);
  }
  const { data: splitData, error: splitError } = await splitQuery;
  if (splitError || !splitData || splitData.length === 0) {
    return "0";
  }

  const splitCounts = new Map<number, number>();
  for (const item of splitData as Array<{ run_id?: unknown }>) {
    const runId = toFiniteNumber(item.run_id);
    if (runId === null) continue;
    const normalizedRunId = Math.floor(runId);
    splitCounts.set(
      normalizedRunId,
      (splitCounts.get(normalizedRunId) ?? 0) + 1,
    );
  }

  let featureQuery = adminClient
    .from("run_segment_ai_features")
    .select("run_id")
    .eq("embedding_status", "completed")
    .limit(10000);
  if (userId) {
    featureQuery = featureQuery.eq("user_id", userId);
  }

  const { data: featureData, error: featureError } = await featureQuery;
  if (featureError || !featureData || featureData.length === 0) {
    return "0";
  }

  const featureCounts = new Map<number, number>();
  for (const item of featureData as Array<{ run_id?: unknown }>) {
    const runId = toFiniteNumber(item.run_id);
    if (runId === null) continue;
    const normalizedRunId = Math.floor(runId);
    featureCounts.set(
      normalizedRunId,
      (featureCounts.get(normalizedRunId) ?? 0) + 1,
    );
  }

  const completedRunIds: string[] = [];
  for (const [runId, splitCount] of splitCounts.entries()) {
    if ((featureCounts.get(runId) ?? 0) >= splitCount) {
      completedRunIds.push(runId.toString());
    }
  }
  return completedRunIds.length > 0 ? completedRunIds.join(",") : "0";
}

async function existingFeatureRunIds(
  adminClient: SupabaseClient,
  userId?: string,
) {
  let query = adminClient
    .from("run_ai_features")
    .select("run_id")
    .limit(10000);
  if (userId) {
    query = query.eq("user_id", userId);
  }

  const { data, error } = await query;
  if (error || !data || data.length === 0) {
    return "0";
  }
  return (data as Array<{ run_id?: unknown }>)
    .map((item: { run_id?: unknown }) => toFiniteNumber(item.run_id))
    .filter((id: number | null): id is number => id !== null)
    .map((id: number) => Math.floor(id).toString())
    .join(",");
}
