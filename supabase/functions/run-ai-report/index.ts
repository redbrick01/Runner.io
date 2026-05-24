import {
  corsHeaders,
  getAuthenticatedClients,
  json,
  toFiniteNumber,
} from "../_shared/run-ai.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET") {
    return json({ error: "Method not allowed" }, { status: 405 });
  }

  const clients = await getAuthenticatedClients(req);
  if ("error" in clients) return clients.error;

  const requestUrl = new URL(req.url);
  const runId = toFiniteNumber(requestUrl.searchParams.get("run_id"));
  const latest = requestUrl.searchParams.get("latest") === "true";

  let query = clients.adminClient
    .from("run_ai_reports")
    .select(
      "run_id,user_id,similar_run_ids,model,summary,improvements,next_goal,coaching_message,comparison,status,error_message,created_at,updated_at",
    )
    .eq("user_id", clients.user.id);

  if (runId !== null && runId > 0) {
    query = query.eq("run_id", Math.floor(runId));
  } else if (latest) {
    query = query.order("created_at", { ascending: false }).limit(1);
  } else {
    query = query.order("created_at", { ascending: false }).limit(10);
  }

  const { data, error } = await query;
  if (error) {
    return json(
      { error: "Failed to fetch AI report", details: error.message },
      { status: 500 },
    );
  }

  if (runId !== null && runId > 0) {
    return json({ report: data?.[0] ?? null });
  }

  if (latest) {
    return json({ report: data?.[0] ?? null });
  }

  return json({ items: data ?? [] });
});
