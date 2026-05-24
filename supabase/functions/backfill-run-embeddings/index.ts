import {
  corsHeaders,
  fetchRunSummary,
  generateEmbedding,
  getAuthenticatedClients,
  json,
  SupabaseClient,
  toFiniteNumber,
  updateFeatureGeometry,
  upsertRunFeatures,
} from "../_shared/run-ai.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, { status: 405 });
  }

  const clients = await getAuthenticatedClients(req);
  if ("error" in clients) return clients.error;

  const requestUrl = new URL(req.url);
  const limitParam = toFiniteNumber(requestUrl.searchParams.get("limit"));
  const limit = Math.min(Math.max(Math.floor(limitParam ?? 20), 1), 50);
  const scope = requestUrl.searchParams.get("scope") ?? "user";
  const isAdminScope = scope === "all";

  if (isAdminScope && !isValidAdminRequest(req)) {
    return json({ error: "Forbidden" }, { status: 403 });
  }

  let query = clients.adminClient
    .from("runs")
    .select("id,user_id")
    .order("started_at", { ascending: true })
    .limit(limit);

  if (isAdminScope) {
    query = query.not(
      "id",
      "in",
      `(${await existingFeatureRunIds(clients.adminClient)})`,
    );
  } else {
    query = query
      .eq("user_id", clients.user.id)
      .not(
        "id",
        "in",
        `(${await existingFeatureRunIds(
          clients.adminClient,
          clients.user.id,
        )})`,
      );
  }

  const { data: runRows, error: runError } = await query;

  if (runError) {
    return json(
      { error: "Failed to fetch runs for backfill", details: runError.message },
      { status: 500 },
    );
  }

  const results: Array<{
    run_id: number;
    user_id?: string;
    status: string;
    error?: string;
  }> = [];
  for (const row of runRows ?? []) {
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
      const embedding = await generateEmbedding(summary.summaryText);
      await upsertRunFeatures(
        clients.adminClient,
        summary,
        embedding,
        "completed",
      );
      await updateFeatureGeometry(clients.adminClient, summary.run.id);
      results.push({
        run_id: summary.run.id,
        user_id: isAdminScope ? summary.run.user_id : undefined,
        status: "completed",
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
    processed: results.length,
    results,
  });
});

function isValidAdminRequest(req: Request): boolean {
  const expected = Deno.env.get("BACKFILL_ADMIN_SECRET");
  const provided = req.headers.get("x-backfill-admin-secret");
  return Boolean(expected && provided && expected === provided);
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
