CREATE OR REPLACE FUNCTION "public"."match_similar_runs"(
    "p_user_id" uuid,
    "p_run_id" bigint,
    "p_embedding" extensions.vector(384),
    "p_numeric_features" jsonb DEFAULT '{}'::jsonb,
    "p_limit" integer DEFAULT 5
) RETURNS TABLE (
    "run_id" bigint,
    "started_at" timestamp without time zone,
    "distance" double precision,
    "duration" double precision,
    "avg_pace" double precision,
    "calories" double precision,
    "area" double precision,
    "point" double precision,
    "summary_text" text,
    "total_ascent_m" double precision,
    "similarity_score" double precision,
    "embedding_score" double precision,
    "numeric_score" double precision,
    "spatial_score" double precision
)
    LANGUAGE sql
    STABLE
    AS $$
WITH target AS (
  SELECT route_centroid
  FROM public.run_ai_features
  WHERE run_id = p_run_id
    AND user_id = p_user_id
  LIMIT 1
),
candidate_scores AS (
  SELECT
    r.id AS run_id,
    r.started_at,
    r.distance,
    r.duration,
    r.avg_pace,
    r.calories,
    r.area,
    r.point,
    f.summary_text,
    f.total_ascent_m,
    CASE
      WHEN p_embedding IS NULL OR f.embedding IS NULL THEN 0::double precision
      ELSE greatest(0::double precision, 1::double precision - (f.embedding OPERATOR(extensions.<=>) p_embedding))
    END AS embedding_score,
    exp(-least(700::double precision, (
      (
        coalesce(abs((f.numeric_features->>'distance_km')::double precision - (p_numeric_features->>'distance_km')::double precision) / 2.0, 0) +
        coalesce(abs((f.numeric_features->>'duration_min')::double precision - (p_numeric_features->>'duration_min')::double precision) / 20.0, 0) +
        coalesce(abs((f.numeric_features->>'avg_pace_s_per_km')::double precision - (p_numeric_features->>'avg_pace_s_per_km')::double precision) / 120.0, 0) +
        coalesce(abs((f.numeric_features->>'total_ascent_m')::double precision - (p_numeric_features->>'total_ascent_m')::double precision) / 100.0, 0) +
        coalesce(abs((f.numeric_features->>'calories')::double precision - (p_numeric_features->>'calories')::double precision) / 250.0, 0) +
        coalesce(abs((f.numeric_features->>'area_m2')::double precision - (p_numeric_features->>'area_m2')::double precision) / 50000.0, 0) +
        coalesce(abs((f.numeric_features->>'split_count')::double precision - (p_numeric_features->>'split_count')::double precision) / 5.0, 0)
      ) / 7.0
    )))::double precision AS numeric_score,
    CASE
      WHEN f.route_centroid IS NULL OR target.route_centroid IS NULL THEN 0::double precision
      ELSE exp(-least(700::double precision, (
        ST_Distance(
          f.route_centroid::geography,
          target.route_centroid::geography
        ) / 2000.0
      )))::double precision
    END AS spatial_score
  FROM public.run_ai_features f
  JOIN public.runs r ON r.id = f.run_id
  CROSS JOIN target
  WHERE f.user_id = p_user_id
    AND f.run_id <> p_run_id
    AND f.embedding_status = 'completed'
)
SELECT
  run_id,
  started_at,
  distance,
  duration,
  avg_pace,
  calories,
  area,
  point,
  summary_text,
  total_ascent_m,
  ((embedding_score * 0.45) + (numeric_score * 0.35) + (spatial_score * 0.20))::double precision AS similarity_score,
  embedding_score,
  numeric_score,
  spatial_score
FROM candidate_scores
ORDER BY similarity_score DESC, started_at DESC
LIMIT greatest(1, least(coalesce(p_limit, 5), 10));
$$;

ALTER FUNCTION "public"."match_similar_runs"(uuid, bigint, extensions.vector(384), jsonb, integer) OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."match_similar_runs"(uuid, bigint, extensions.vector(384), jsonb, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."match_similar_runs"(uuid, bigint, extensions.vector(384), jsonb, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."match_similar_runs"(uuid, bigint, extensions.vector(384), jsonb, integer) TO "service_role";
