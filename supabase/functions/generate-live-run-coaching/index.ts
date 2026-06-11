import {
  buildFallbackLiveCoaching,
  buildLiveSegmentSnapshot,
  callOpenAiLiveCoaching,
  corsHeaders,
  generateEmbedding,
  getAuthenticatedClients,
  isRecord,
  json,
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

  const snapshot = buildLiveSegmentSnapshot(payload);
  if (
    snapshot.completedKm <= 0 ||
    snapshot.splitPaceSeconds <= 0 ||
    snapshot.averagePaceSeconds <= 0
  ) {
    return json({
      status: "failed",
      coaching_message: "페이스 측정이 불안정해요. 리듬만 편하게 유지해보세요.",
      coaching_category: "steady",
      similar_segment_count: 0,
      fallback_used: true,
    });
  }

  try {
    const embedding = await generateEmbedding(snapshot.summaryText);
    const { data: similarData, error: similarError } = await clients.adminClient
      .rpc("match_similar_run_segments", {
        p_user_id: clients.user.id,
        p_split_index: snapshot.splitIndex,
        p_embedding: JSON.stringify(embedding),
        p_feature_json: snapshot.featureJson,
        p_exclude_run_id: snapshot.excludeRunId,
        p_limit: 5,
      });

    if (similarError) {
      throw new Error(
        `Segment similarity search failed: ${similarError.message}`,
      );
    }

    const similarSegments = Array.isArray(similarData)
      ? similarData.slice(0, 5).filter(isRecord)
      : [];

    if (similarSegments.length < 3) {
      return json(buildFallbackLiveCoaching(snapshot, similarSegments));
    }

    try {
      return json(await callOpenAiLiveCoaching(snapshot, similarSegments));
    } catch (llmError) {
      console.warn(
        "Live coaching LLM failed",
        llmError instanceof Error ? llmError.message : String(llmError),
      );
      return json(buildFallbackLiveCoaching(snapshot, similarSegments));
    }
  } catch (error) {
    console.warn(
      "Live coaching fallback",
      error instanceof Error ? error.message : String(error),
    );
    return json(buildFallbackLiveCoaching(snapshot, [], true));
  }
});
