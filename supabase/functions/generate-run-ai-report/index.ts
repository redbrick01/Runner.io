import {
  buildFallbackReport,
  callOpenAiReport,
  corsHeaders,
  fetchRunSummary,
  generateEmbedding,
  getAuthenticatedClients,
  isRecord,
  json,
  normalizeReport,
  toFiniteNumber,
  updateFeatureGeometry,
  upsertRunFeatures,
  upsertRunReport,
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

  const payload = await req.json().catch(() => null);
  if (!isRecord(payload)) {
    return json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const runId = toFiniteNumber(payload.run_id);
  if (runId === null || runId <= 0) {
    return json({ error: "run_id is required" }, { status: 400 });
  }

  try {
    const summary = await fetchRunSummary(
      clients.adminClient,
      clients.user.id,
      Math.floor(runId),
    );
    if (!summary) {
      return json({ error: "Run not found" }, { status: 404 });
    }

    let embedding: number[] | null = null;
    try {
      embedding = await generateEmbedding(summary.summaryText);
      await upsertRunFeatures(
        clients.adminClient,
        summary,
        embedding,
        "completed",
      );
      await updateFeatureGeometry(clients.adminClient, summary.run.id);
    } catch (embeddingError) {
      const message = embeddingError instanceof Error
        ? embeddingError.message
        : "Embedding failed";
      await upsertRunFeatures(
        clients.adminClient,
        summary,
        null,
        "failed",
        message,
      );
      const failedReport = buildFallbackReport(
        summary,
        [],
        "failed",
        message,
      );
      await upsertRunReport(clients.adminClient, failedReport);
      return json({ report: failedReport }, { status: 200 });
    }

    const { data: similarData, error: similarError } = await clients.adminClient
      .rpc("match_similar_runs", {
        p_user_id: clients.user.id,
        p_run_id: summary.run.id,
        p_embedding: JSON.stringify(embedding),
        p_numeric_features: summary.numericFeatures,
        p_limit: 5,
      });

    if (similarError) {
      throw new Error(`Similarity search failed: ${similarError.message}`);
    }

    const similarRuns = Array.isArray(similarData)
      ? similarData.slice(0, 5).filter(isRecord)
      : [];

    if (similarRuns.length < 3) {
      const insufficientReport = buildFallbackReport(
        summary,
        similarRuns,
        "insufficient_data",
      );
      await upsertRunReport(clients.adminClient, insufficientReport);
      return json({ report: insufficientReport }, { status: 200 });
    }

    try {
      const llmReport = await callOpenAiReport(summary, similarRuns);
      const report = normalizeReport(summary, similarRuns, llmReport);
      await upsertRunReport(clients.adminClient, report);
      return json({ report }, { status: 200 });
    } catch (llmError) {
      const message = llmError instanceof Error
        ? llmError.message
        : "LLM failed";
      const fallbackReport = buildFallbackReport(
        summary,
        similarRuns,
        "failed",
        message,
      );
      await upsertRunReport(clients.adminClient, fallbackReport);
      return json({ report: fallbackReport }, { status: 200 });
    }
  } catch (error) {
    console.error(error);
    return json(
      {
        error: "Failed to generate AI report",
        details: error instanceof Error ? error.message : String(error),
      },
      { status: 500 },
    );
  }
});
