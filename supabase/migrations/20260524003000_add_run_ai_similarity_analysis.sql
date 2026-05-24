CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "extensions";

CREATE TABLE IF NOT EXISTS "public"."run_ai_features" (
    "run_id" bigint NOT NULL,
    "user_id" uuid NOT NULL,
    "embedding" extensions.vector(384),
    "numeric_features" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "summary_text" text NOT NULL,
    "total_ascent_m" double precision,
    "pace_variance" double precision,
    "route_centroid" "public"."geometry"(Point, 4326),
    "route_bbox" "public"."geometry"(Polygon, 4326),
    "embedding_model" text DEFAULT 'gte-small'::text NOT NULL,
    "embedding_status" text DEFAULT 'pending'::text NOT NULL,
    "error_message" text,
    "embedded_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "run_ai_features_embedding_status_chk" CHECK (
        "embedding_status" = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text])
    )
);

ALTER TABLE "public"."run_ai_features" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."run_ai_reports" (
    "run_id" bigint NOT NULL,
    "user_id" uuid NOT NULL,
    "similar_run_ids" bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    "model" text DEFAULT 'gpt-5.4-mini'::text NOT NULL,
    "summary" text NOT NULL,
    "improvements" jsonb DEFAULT '[]'::jsonb NOT NULL,
    "next_goal" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "coaching_message" text NOT NULL,
    "comparison" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "status" text DEFAULT 'completed'::text NOT NULL,
    "error_message" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "run_ai_reports_status_chk" CHECK (
        "status" = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'insufficient_data'::text])
    )
);

ALTER TABLE "public"."run_ai_reports" OWNER TO "postgres";

ALTER TABLE ONLY "public"."run_ai_features"
    ADD CONSTRAINT "run_ai_features_pkey" PRIMARY KEY ("run_id");

ALTER TABLE ONLY "public"."run_ai_reports"
    ADD CONSTRAINT "run_ai_reports_pkey" PRIMARY KEY ("run_id");

ALTER TABLE ONLY "public"."run_ai_features"
    ADD CONSTRAINT "run_ai_features_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "public"."runs"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."run_ai_features"
    ADD CONSTRAINT "run_ai_features_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."run_ai_reports"
    ADD CONSTRAINT "run_ai_reports_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "public"."runs"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."run_ai_reports"
    ADD CONSTRAINT "run_ai_reports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("user_id") ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS "idx_run_ai_features_user_id"
    ON "public"."run_ai_features" USING btree ("user_id");

CREATE INDEX IF NOT EXISTS "idx_run_ai_features_status"
    ON "public"."run_ai_features" USING btree ("embedding_status", "created_at");

CREATE INDEX IF NOT EXISTS "idx_run_ai_features_route_centroid_gist"
    ON "public"."run_ai_features" USING gist ("route_centroid");

CREATE INDEX IF NOT EXISTS "idx_run_ai_features_embedding_ivfflat"
    ON "public"."run_ai_features" USING ivfflat ("embedding" extensions.vector_cosine_ops)
    WITH (lists = 100)
    WHERE "embedding" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "idx_run_ai_reports_user_created"
    ON "public"."run_ai_reports" USING btree ("user_id", "created_at" DESC);

CREATE INDEX IF NOT EXISTS "idx_runs_path_geom_gist"
    ON "public"."runs" USING gist ("path_geom");

CREATE OR REPLACE FUNCTION "public"."set_run_ai_updated_at"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."set_run_ai_updated_at"() OWNER TO "postgres";

CREATE OR REPLACE TRIGGER "trg_run_ai_features_updated_at"
    BEFORE UPDATE ON "public"."run_ai_features"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_run_ai_updated_at"();

CREATE OR REPLACE TRIGGER "trg_run_ai_reports_updated_at"
    BEFORE UPDATE ON "public"."run_ai_reports"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_run_ai_updated_at"();

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
    exp(-(
      (
        coalesce(abs((f.numeric_features->>'distance_km')::double precision - (p_numeric_features->>'distance_km')::double precision) / 2.0, 0) +
        coalesce(abs((f.numeric_features->>'duration_min')::double precision - (p_numeric_features->>'duration_min')::double precision) / 20.0, 0) +
        coalesce(abs((f.numeric_features->>'avg_pace_s_per_km')::double precision - (p_numeric_features->>'avg_pace_s_per_km')::double precision) / 120.0, 0) +
        coalesce(abs((f.numeric_features->>'total_ascent_m')::double precision - (p_numeric_features->>'total_ascent_m')::double precision) / 100.0, 0) +
        coalesce(abs((f.numeric_features->>'calories')::double precision - (p_numeric_features->>'calories')::double precision) / 250.0, 0) +
        coalesce(abs((f.numeric_features->>'area_m2')::double precision - (p_numeric_features->>'area_m2')::double precision) / 50000.0, 0) +
        coalesce(abs((f.numeric_features->>'split_count')::double precision - (p_numeric_features->>'split_count')::double precision) / 5.0, 0)
      ) / 7.0
    ))::double precision AS numeric_score,
    CASE
      WHEN f.route_centroid IS NULL OR target.route_centroid IS NULL THEN 0::double precision
      ELSE exp(-(
        ST_Distance(
          f.route_centroid::geography,
          target.route_centroid::geography
        ) / 2000.0
      ))::double precision
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

CREATE OR REPLACE FUNCTION "public"."set_run_ai_feature_geometry"(
    "p_run_id" bigint
) RETURNS void
    LANGUAGE sql
    SECURITY DEFINER
    AS $$
UPDATE public.run_ai_features f
SET
  route_centroid = ST_SetSRID(ST_PointOnSurface(ST_Envelope(ST_Force2D(r.path_geom))), 4326),
  route_bbox = ST_SetSRID(ST_Envelope(ST_Force2D(r.path_geom)), 4326)
FROM public.runs r
WHERE r.id = f.run_id
  AND f.run_id = p_run_id
  AND r.path_geom IS NOT NULL;
$$;

ALTER FUNCTION "public"."set_run_ai_feature_geometry"(bigint) OWNER TO "postgres";

GRANT ALL ON TABLE "public"."run_ai_features" TO "anon";
GRANT ALL ON TABLE "public"."run_ai_features" TO "authenticated";
GRANT ALL ON TABLE "public"."run_ai_features" TO "service_role";

GRANT ALL ON TABLE "public"."run_ai_reports" TO "anon";
GRANT ALL ON TABLE "public"."run_ai_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."run_ai_reports" TO "service_role";

GRANT ALL ON FUNCTION "public"."set_run_ai_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_run_ai_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_run_ai_updated_at"() TO "service_role";

GRANT ALL ON FUNCTION "public"."match_similar_runs"(uuid, bigint, extensions.vector(384), jsonb, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."match_similar_runs"(uuid, bigint, extensions.vector(384), jsonb, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."match_similar_runs"(uuid, bigint, extensions.vector(384), jsonb, integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."set_run_ai_feature_geometry"(bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."set_run_ai_feature_geometry"(bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_run_ai_feature_geometry"(bigint) TO "service_role";
