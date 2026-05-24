-- Fix remote Supabase lint/advisor issues found on 2026-05-24.
-- Scope:
-- - Replace the broken zero-argument territory maintenance RPC.
-- - Enable RLS on app-owned exposed public tables with owner-scoped policies.
-- - Remove direct anon/authenticated access to internal SECURITY DEFINER RPCs.
-- - Pin app-owned function search_path values.
-- - Drop the duplicate territories(user_id) uniqueness constraint.

CREATE OR REPLACE FUNCTION "public"."apply_territory_points"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = public, extensions
    AS $$
BEGIN
  PERFORM public.apply_territory_worker();
END;
$$;

ALTER FUNCTION "public"."apply_territory_points"() OWNER TO "postgres";

ALTER FUNCTION "public"."apply_territory_points"("p_user_ids" "uuid"[])
  SET search_path = public, extensions;
ALTER FUNCTION "public"."apply_territory_worker"()
  SET search_path = public, extensions;
ALTER FUNCTION "public"."clean_geom"("public"."geometry")
  SET search_path = public, extensions;
ALTER FUNCTION "public"."compute_area_and_base"("public"."geometry")
  SET search_path = public, extensions;
ALTER FUNCTION "public"."create_profile_after_auth_insert"()
  SET search_path = public, extensions;
ALTER FUNCTION "public"."create_profile_after_signup"()
  SET search_path = public, extensions;
ALTER FUNCTION "public"."geom_to_polygon"("public"."geometry")
  SET search_path = public, extensions;
ALTER FUNCTION "public"."get_best_utm_srid"("public"."geometry")
  SET search_path = public, extensions;
ALTER FUNCTION "public"."get_profile_rank_count"("uuid")
  SET search_path = public, extensions;
ALTER FUNCTION "public"."get_territories_geojson"(
  integer,
  double precision,
  double precision,
  double precision,
  double precision,
  integer
) SET search_path = public, extensions;
ALTER FUNCTION "public"."get_territory_weight"(timestamp with time zone)
  SET search_path = public, extensions;
ALTER FUNCTION "public"."get_user_info"("uuid")
  SET search_path = public, extensions;
ALTER FUNCTION "public"."handle_run_points"()
  SET search_path = public, extensions;
ALTER FUNCTION "public"."handle_territory_schedule"()
  SET search_path = public, extensions;
ALTER FUNCTION "public"."match_similar_runs"(
  "uuid",
  bigint,
  extensions.vector,
  jsonb,
  integer
) SET search_path = public, extensions;
ALTER FUNCTION "public"."process_run_geometry"()
  SET search_path = public, extensions;
ALTER FUNCTION "public"."run_apply_territory_points_with_lock"(bigint)
  SET search_path = public, extensions;
ALTER FUNCTION "public"."set_run_ai_feature_geometry"(bigint)
  SET search_path = public, extensions;
ALTER FUNCTION "public"."set_run_ai_updated_at"()
  SET search_path = public, extensions;
ALTER FUNCTION "public"."set_updated_at_user_point_daily"()
  SET search_path = public, extensions;
ALTER FUNCTION "public"."subtract_territory_and_update"("public"."geometry", "uuid")
  SET search_path = public, extensions;
ALTER FUNCTION "public"."upsert_or_merge_territory"("public"."geometry", "uuid")
  SET search_path = public, extensions;

ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."point_history" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."runs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."territories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."user_point_daily" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."run_ai_features" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."run_splits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."run_ai_reports" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON "public"."profiles";
CREATE POLICY "profiles_select_own"
  ON "public"."profiles"
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "profiles_update_own" ON "public"."profiles";
CREATE POLICY "profiles_update_own"
  ON "public"."profiles"
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "runs_select_own" ON "public"."runs";
CREATE POLICY "runs_select_own"
  ON "public"."runs"
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "runs_insert_own" ON "public"."runs";
CREATE POLICY "runs_insert_own"
  ON "public"."runs"
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "runs_delete_own" ON "public"."runs";
CREATE POLICY "runs_delete_own"
  ON "public"."runs"
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "run_splits_select_own" ON "public"."run_splits";
CREATE POLICY "run_splits_select_own"
  ON "public"."run_splits"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.runs r
      WHERE r.id = run_splits.run_id
        AND r.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "run_splits_insert_own" ON "public"."run_splits";
CREATE POLICY "run_splits_insert_own"
  ON "public"."run_splits"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.runs r
      WHERE r.id = run_splits.run_id
        AND r.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "point_history_select_own" ON "public"."point_history";
CREATE POLICY "point_history_select_own"
  ON "public"."point_history"
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "territories_select_own" ON "public"."territories";
CREATE POLICY "territories_select_own"
  ON "public"."territories"
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_point_daily_select_own" ON "public"."user_point_daily";
CREATE POLICY "user_point_daily_select_own"
  ON "public"."user_point_daily"
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "run_ai_features_select_own" ON "public"."run_ai_features";
CREATE POLICY "run_ai_features_select_own"
  ON "public"."run_ai_features"
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "run_ai_reports_select_own" ON "public"."run_ai_reports";
CREATE POLICY "run_ai_reports_select_own"
  ON "public"."run_ai_reports"
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

REVOKE EXECUTE ON FUNCTION "public"."apply_territory_points"() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION "public"."apply_territory_worker"() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION "public"."create_profile_after_auth_insert"() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION "public"."create_profile_after_signup"() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION "public"."run_apply_territory_points_with_lock"(bigint) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION "public"."set_run_ai_feature_geometry"(bigint) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION "public"."st_estimatedextent"(text, text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION "public"."st_estimatedextent"(text, text, text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION "public"."st_estimatedextent"(text, text, text, boolean) FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."apply_territory_points"() TO service_role;
GRANT EXECUTE ON FUNCTION "public"."apply_territory_worker"() TO service_role;
GRANT EXECUTE ON FUNCTION "public"."create_profile_after_auth_insert"() TO service_role;
GRANT EXECUTE ON FUNCTION "public"."create_profile_after_signup"() TO service_role;
GRANT EXECUTE ON FUNCTION "public"."run_apply_territory_points_with_lock"(bigint) TO service_role;
GRANT EXECUTE ON FUNCTION "public"."set_run_ai_feature_geometry"(bigint) TO service_role;

ALTER TABLE "public"."territories"
  DROP CONSTRAINT IF EXISTS "territories_user_id_key";
