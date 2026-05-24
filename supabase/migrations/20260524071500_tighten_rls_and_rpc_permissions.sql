-- Follow-up hardening after enabling RLS.
-- Supabase advisors treat PUBLIC execute grants as inherited by anon/authenticated.
-- RLS auth helper calls are wrapped in SELECT to avoid per-row initplan warnings.

DROP POLICY IF EXISTS "profiles_select_own" ON "public"."profiles";
CREATE POLICY "profiles_select_own"
  ON "public"."profiles"
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "profiles_update_own" ON "public"."profiles";
CREATE POLICY "profiles_update_own"
  ON "public"."profiles"
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "runs_select_own" ON "public"."runs";
CREATE POLICY "runs_select_own"
  ON "public"."runs"
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "runs_insert_own" ON "public"."runs";
CREATE POLICY "runs_insert_own"
  ON "public"."runs"
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "runs_delete_own" ON "public"."runs";
CREATE POLICY "runs_delete_own"
  ON "public"."runs"
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

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
        AND r.user_id = (SELECT auth.uid())
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
        AND r.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS "point_history_select_own" ON "public"."point_history";
CREATE POLICY "point_history_select_own"
  ON "public"."point_history"
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "territories_select_own" ON "public"."territories";
CREATE POLICY "territories_select_own"
  ON "public"."territories"
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_point_daily_select_own" ON "public"."user_point_daily";
CREATE POLICY "user_point_daily_select_own"
  ON "public"."user_point_daily"
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "run_ai_features_select_own" ON "public"."run_ai_features";
CREATE POLICY "run_ai_features_select_own"
  ON "public"."run_ai_features"
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "run_ai_reports_select_own" ON "public"."run_ai_reports";
CREATE POLICY "run_ai_reports_select_own"
  ON "public"."run_ai_reports"
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

REVOKE EXECUTE ON FUNCTION "public"."apply_territory_points"() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION "public"."apply_territory_worker"() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION "public"."create_profile_after_auth_insert"() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION "public"."create_profile_after_signup"() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION "public"."run_apply_territory_points_with_lock"(bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION "public"."set_run_ai_feature_geometry"(bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION "public"."st_estimatedextent"(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION "public"."st_estimatedextent"(text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION "public"."st_estimatedextent"(text, text, text, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."apply_territory_points"() TO service_role;
GRANT EXECUTE ON FUNCTION "public"."apply_territory_worker"() TO service_role;
GRANT EXECUTE ON FUNCTION "public"."create_profile_after_auth_insert"() TO service_role;
GRANT EXECUTE ON FUNCTION "public"."create_profile_after_signup"() TO service_role;
GRANT EXECUTE ON FUNCTION "public"."run_apply_territory_points_with_lock"(bigint) TO service_role;
GRANT EXECUTE ON FUNCTION "public"."set_run_ai_feature_geometry"(bigint) TO service_role;
