-- Social crew RPC helpers.
-- These functions keep crew ranking and default-selection consistency in
-- Postgres instead of loading unbounded contribution history in Edge Functions.

CREATE INDEX IF NOT EXISTS crew_members_crew_active_idx
  ON public.crew_members (crew_id)
  WHERE left_at IS NULL;

CREATE OR REPLACE FUNCTION public.social_crew_summaries(
  p_user_id uuid,
  p_q text,
  p_region text,
  p_sort text,
  p_limit integer,
  p_season_from timestamptz,
  p_season_to_exclusive timestamptz
)
RETURNS TABLE (
  id uuid,
  name text,
  description text,
  region text,
  color_hex text,
  member_count integer,
  season_score double precision,
  cumulative_area_m2 double precision,
  is_joined boolean,
  is_default_contribution boolean,
  last_contributed_at timestamptz,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
WITH filtered_crews AS (
  SELECT c.id,
         c.name,
         c.description,
         c.region,
         c.color_hex,
         c.created_at
  FROM public.crews c
  WHERE c.is_public = true
    AND c.deleted_at IS NULL
    AND (
      NULLIF(BTRIM(p_q), '') IS NULL
      OR c.name ILIKE ('%' || BTRIM(p_q) || '%')
      OR COALESCE(c.region, '') ILIKE ('%' || BTRIM(p_q) || '%')
    )
    AND (
      NULLIF(BTRIM(p_region), '') IS NULL
      OR COALESCE(c.region, '') ILIKE ('%' || BTRIM(p_region) || '%')
    )
),
active_member_counts AS (
  SELECT cm.crew_id,
         COUNT(*)::integer AS member_count
  FROM public.crew_members cm
  JOIN filtered_crews fc ON fc.id = cm.crew_id
  WHERE cm.left_at IS NULL
  GROUP BY cm.crew_id
),
viewer_memberships AS (
  SELECT cm.crew_id,
         cm.is_default_contribution
  FROM public.crew_members cm
  JOIN filtered_crews fc ON fc.id = cm.crew_id
  WHERE cm.user_id = p_user_id
    AND cm.left_at IS NULL
),
season_contributions AS (
  SELECT rcc.crew_id,
         COALESCE(SUM(rcc.contribution_score), 0)::double precision AS season_score
  FROM public.run_crew_contributions rcc
  JOIN filtered_crews fc ON fc.id = rcc.crew_id
  WHERE rcc.created_at >= p_season_from
    AND rcc.created_at < p_season_to_exclusive
  GROUP BY rcc.crew_id
),
cumulative_contributions AS (
  SELECT rcc.crew_id,
         COALESCE(SUM(rcc.contribution_area_m2), 0)::double precision AS cumulative_area_m2,
         MAX(rcc.created_at) AS last_contribution_at
  FROM public.run_crew_contributions rcc
  JOIN filtered_crews fc ON fc.id = rcc.crew_id
  GROUP BY rcc.crew_id
),
member_activity AS (
  SELECT cm.crew_id,
         MAX(cm.last_contributed_at) AS last_member_contribution_at
  FROM public.crew_members cm
  JOIN filtered_crews fc ON fc.id = cm.crew_id
  WHERE cm.left_at IS NULL
  GROUP BY cm.crew_id
),
summary AS (
  SELECT fc.id,
         fc.name,
         fc.description,
         fc.region,
         fc.color_hex,
         COALESCE(amc.member_count, 0)::integer AS member_count,
         COALESCE(sc.season_score, 0)::double precision AS season_score,
         COALESCE(cc.cumulative_area_m2, 0)::double precision AS cumulative_area_m2,
         (vm.crew_id IS NOT NULL) AS is_joined,
         COALESCE(vm.is_default_contribution, false) AS is_default_contribution,
         GREATEST(ma.last_member_contribution_at, cc.last_contribution_at) AS last_contributed_at,
         fc.created_at
  FROM filtered_crews fc
  LEFT JOIN active_member_counts amc ON amc.crew_id = fc.id
  LEFT JOIN viewer_memberships vm ON vm.crew_id = fc.id
  LEFT JOIN season_contributions sc ON sc.crew_id = fc.id
  LEFT JOIN cumulative_contributions cc ON cc.crew_id = fc.id
  LEFT JOIN member_activity ma ON ma.crew_id = fc.id
)
SELECT summary.id,
       summary.name,
       summary.description,
       summary.region,
       summary.color_hex,
       summary.member_count,
       summary.season_score,
       summary.cumulative_area_m2,
       summary.is_joined,
       summary.is_default_contribution,
       summary.last_contributed_at,
       summary.created_at
FROM summary
ORDER BY
  CASE WHEN LOWER(COALESCE(p_sort, 'score')) = 'members' THEN summary.member_count END DESC NULLS LAST,
  CASE WHEN LOWER(COALESCE(p_sort, 'score')) = 'activity' THEN summary.last_contributed_at END DESC NULLS LAST,
  CASE WHEN LOWER(COALESCE(p_sort, 'score')) = 'new' THEN summary.created_at END DESC NULLS LAST,
  summary.season_score DESC,
  summary.cumulative_area_m2 DESC,
  summary.name ASC,
  summary.id ASC
LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
$$;

ALTER FUNCTION public.social_crew_summaries(
  uuid,
  text,
  text,
  text,
  integer,
  timestamptz,
  timestamptz
) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.social_crew_summaries_by_ids(
  p_user_id uuid,
  p_crew_ids uuid[],
  p_season_from timestamptz,
  p_season_to_exclusive timestamptz
)
RETURNS TABLE (
  id uuid,
  name text,
  description text,
  region text,
  color_hex text,
  member_count integer,
  season_score double precision,
  cumulative_area_m2 double precision,
  is_joined boolean,
  is_default_contribution boolean,
  last_contributed_at timestamptz,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
WITH requested_ids AS (
  SELECT UNNEST(COALESCE(p_crew_ids, ARRAY[]::uuid[])) AS crew_id
),
filtered_crews AS (
  SELECT c.id,
         c.name,
         c.description,
         c.region,
         c.color_hex,
         c.created_at
  FROM public.crews c
  JOIN requested_ids ri ON ri.crew_id = c.id
  WHERE c.is_public = true
    AND c.deleted_at IS NULL
),
active_member_counts AS (
  SELECT cm.crew_id,
         COUNT(*)::integer AS member_count
  FROM public.crew_members cm
  JOIN filtered_crews fc ON fc.id = cm.crew_id
  WHERE cm.left_at IS NULL
  GROUP BY cm.crew_id
),
viewer_memberships AS (
  SELECT cm.crew_id,
         cm.is_default_contribution
  FROM public.crew_members cm
  JOIN filtered_crews fc ON fc.id = cm.crew_id
  WHERE cm.user_id = p_user_id
    AND cm.left_at IS NULL
),
season_contributions AS (
  SELECT rcc.crew_id,
         COALESCE(SUM(rcc.contribution_score), 0)::double precision AS season_score
  FROM public.run_crew_contributions rcc
  JOIN filtered_crews fc ON fc.id = rcc.crew_id
  WHERE rcc.created_at >= p_season_from
    AND rcc.created_at < p_season_to_exclusive
  GROUP BY rcc.crew_id
),
cumulative_contributions AS (
  SELECT rcc.crew_id,
         COALESCE(SUM(rcc.contribution_area_m2), 0)::double precision AS cumulative_area_m2,
         MAX(rcc.created_at) AS last_contribution_at
  FROM public.run_crew_contributions rcc
  JOIN filtered_crews fc ON fc.id = rcc.crew_id
  GROUP BY rcc.crew_id
),
member_activity AS (
  SELECT cm.crew_id,
         MAX(cm.last_contributed_at) AS last_member_contribution_at
  FROM public.crew_members cm
  JOIN filtered_crews fc ON fc.id = cm.crew_id
  WHERE cm.left_at IS NULL
  GROUP BY cm.crew_id
)
SELECT fc.id,
       fc.name,
       fc.description,
       fc.region,
       fc.color_hex,
       COALESCE(amc.member_count, 0)::integer AS member_count,
       COALESCE(sc.season_score, 0)::double precision AS season_score,
       COALESCE(cc.cumulative_area_m2, 0)::double precision AS cumulative_area_m2,
       (vm.crew_id IS NOT NULL) AS is_joined,
       COALESCE(vm.is_default_contribution, false) AS is_default_contribution,
       GREATEST(ma.last_member_contribution_at, cc.last_contribution_at) AS last_contributed_at,
       fc.created_at
FROM filtered_crews fc
LEFT JOIN active_member_counts amc ON amc.crew_id = fc.id
LEFT JOIN viewer_memberships vm ON vm.crew_id = fc.id
LEFT JOIN season_contributions sc ON sc.crew_id = fc.id
LEFT JOIN cumulative_contributions cc ON cc.crew_id = fc.id
LEFT JOIN member_activity ma ON ma.crew_id = fc.id
ORDER BY ARRAY_POSITION(p_crew_ids, fc.id), fc.created_at DESC, fc.id ASC;
$$;

ALTER FUNCTION public.social_crew_summaries_by_ids(
  uuid,
  uuid[],
  timestamptz,
  timestamptz
) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.social_crew_member_contributions(
  p_crew_id uuid,
  p_season_from timestamptz,
  p_season_to_exclusive timestamptz,
  p_limit integer
)
RETURNS TABLE (
  user_id uuid,
  nick_name text,
  color_hex text,
  contribution_score double precision,
  contribution_area_m2 double precision,
  display_rank integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
WITH target_crew AS (
  SELECT c.id
  FROM public.crews c
  WHERE c.id = p_crew_id
    AND c.is_public = true
    AND c.deleted_at IS NULL
),
active_members AS (
  SELECT cm.user_id
  FROM public.crew_members cm
  JOIN target_crew tc ON tc.id = cm.crew_id
  WHERE cm.left_at IS NULL
),
season_totals AS (
  SELECT rcc.user_id,
         COALESCE(SUM(rcc.contribution_score), 0)::double precision AS contribution_score,
         COALESCE(SUM(rcc.contribution_area_m2), 0)::double precision AS contribution_area_m2
  FROM public.run_crew_contributions rcc
  JOIN target_crew tc ON tc.id = rcc.crew_id
  WHERE rcc.created_at >= p_season_from
    AND rcc.created_at < p_season_to_exclusive
  GROUP BY rcc.user_id
),
ranked_members AS (
  SELECT am.user_id,
         p.nick_name,
         p.color_hex,
         COALESCE(st.contribution_score, 0)::double precision AS contribution_score,
         COALESCE(st.contribution_area_m2, 0)::double precision AS contribution_area_m2
  FROM active_members am
  LEFT JOIN season_totals st ON st.user_id = am.user_id
  LEFT JOIN public.profiles p ON p.user_id = am.user_id
)
SELECT ranked_members.user_id,
       ranked_members.nick_name,
       ranked_members.color_hex,
       ranked_members.contribution_score,
       ranked_members.contribution_area_m2,
       RANK() OVER (
         ORDER BY
           ranked_members.contribution_score DESC,
           ranked_members.contribution_area_m2 DESC
       )::integer AS display_rank
FROM ranked_members
ORDER BY
  ranked_members.contribution_score DESC,
  ranked_members.contribution_area_m2 DESC,
  ranked_members.user_id ASC
LIMIT LEAST(
  CASE WHEN COALESCE(p_limit, 0) <= 0 THEN 50 ELSE p_limit END,
  100
);
$$;

ALTER FUNCTION public.social_crew_member_contributions(
  uuid,
  timestamptz,
  timestamptz,
  integer
) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.set_default_crew(
  p_user_id uuid,
  p_crew_id uuid
)
RETURNS TABLE (
  id uuid,
  crew_id uuid,
  user_id uuid,
  joined_at timestamptz,
  is_default_contribution boolean,
  last_contributed_at timestamptz,
  left_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Lock all active memberships for this user so clearing and setting the
  -- default crew happens atomically with the partial unique index.
  PERFORM 1
  FROM public.crew_members cm
  WHERE cm.user_id = p_user_id
    AND cm.left_at IS NULL
  FOR UPDATE;

  IF NOT EXISTS (
    SELECT 1
    FROM public.crew_members cm
    WHERE cm.user_id = p_user_id
      AND cm.crew_id = p_crew_id
      AND cm.left_at IS NULL
  ) THEN
    RETURN;
  END IF;

  UPDATE public.crew_members cm
  SET is_default_contribution = false
  WHERE cm.user_id = p_user_id
    AND cm.left_at IS NULL
    AND cm.is_default_contribution = true;

  RETURN QUERY
  UPDATE public.crew_members cm
  SET is_default_contribution = true
  WHERE cm.user_id = p_user_id
    AND cm.crew_id = p_crew_id
    AND cm.left_at IS NULL
  RETURNING
    cm.id,
    cm.crew_id,
    cm.user_id,
    cm.joined_at,
    cm.is_default_contribution,
    cm.last_contributed_at,
    cm.left_at;
END;
$$;

ALTER FUNCTION public.set_default_crew(uuid, uuid) OWNER TO "postgres";

COMMENT ON FUNCTION public.social_crew_summaries(
  uuid,
  text,
  text,
  text,
  integer,
  timestamptz,
  timestamptz
) IS
  'Returns public non-deleted crew summaries with member, season, cumulative, membership, and activity metrics aggregated in Postgres.';

COMMENT ON FUNCTION public.social_crew_summaries_by_ids(
  uuid,
  uuid[],
  timestamptz,
  timestamptz
) IS
  'Returns public non-deleted crew summaries for specific crew IDs with metrics aggregated in Postgres.';

COMMENT ON FUNCTION public.social_crew_member_contributions(
  uuid,
  timestamptz,
  timestamptz,
  integer
) IS
  'Returns bounded active-member contribution rankings for a public non-deleted crew in one season window.';

COMMENT ON FUNCTION public.set_default_crew(uuid, uuid) IS
  'Atomically makes one active crew membership the default contribution crew for a user.';

REVOKE ALL ON FUNCTION public.social_crew_summaries(
  uuid,
  text,
  text,
  text,
  integer,
  timestamptz,
  timestamptz
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.social_crew_summaries_by_ids(
  uuid,
  uuid[],
  timestamptz,
  timestamptz
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.social_crew_member_contributions(
  uuid,
  timestamptz,
  timestamptz,
  integer
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_default_crew(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.social_crew_summaries(
  uuid,
  text,
  text,
  text,
  integer,
  timestamptz,
  timestamptz
) TO service_role;
GRANT EXECUTE ON FUNCTION public.social_crew_summaries_by_ids(
  uuid,
  uuid[],
  timestamptz,
  timestamptz
) TO service_role;
GRANT EXECUTE ON FUNCTION public.social_crew_member_contributions(
  uuid,
  timestamptz,
  timestamptz,
  integer
) TO service_role;
GRANT EXECUTE ON FUNCTION public.set_default_crew(uuid, uuid)
  TO service_role;
