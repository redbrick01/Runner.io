-- Social crew territory foundation.
-- Mutations for these tables are intentionally routed through service-role
-- Edge Functions so auth, validation, and ranking side effects stay server-side.

CREATE OR REPLACE FUNCTION "public"."generate_friend_code"()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  candidate text;
BEGIN
  LOOP
    candidate := upper(substr(replace(extensions.gen_random_uuid()::text, '-', ''), 1, 8));

    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE friend_code = candidate
    );
  END LOOP;

  RETURN candidate;
END;
$$;

ALTER FUNCTION "public"."generate_friend_code"() OWNER TO "postgres";
REVOKE ALL ON FUNCTION "public"."generate_friend_code"() FROM PUBLIC;
REVOKE ALL ON FUNCTION "public"."generate_friend_code"() FROM anon;
REVOKE ALL ON FUNCTION "public"."generate_friend_code"() FROM authenticated;
GRANT EXECUTE ON FUNCTION "public"."generate_friend_code"() TO service_role;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS friend_code text;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_friend_code_key
  ON public.profiles (friend_code)
  WHERE friend_code IS NOT NULL;

ALTER TABLE public.profiles
  ALTER COLUMN friend_code SET DEFAULT public.generate_friend_code();

UPDATE public.profiles
SET friend_code = public.generate_friend_code()
WHERE friend_code IS NULL;

ALTER TABLE public.profiles
  ALTER COLUMN friend_code SET NOT NULL;

CREATE OR REPLACE FUNCTION public.prevent_friend_code_client_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.friend_code IS DISTINCT FROM OLD.friend_code
     AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
    RAISE EXCEPTION 'friend_code is server-controlled'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.prevent_friend_code_client_update() OWNER TO "postgres";

DROP TRIGGER IF EXISTS profiles_prevent_friend_code_client_update ON public.profiles;
CREATE TRIGGER profiles_prevent_friend_code_client_update
  BEFORE UPDATE OF friend_code ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_friend_code_client_update();

CREATE TABLE IF NOT EXISTS public.friendships (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  CONSTRAINT friendships_no_self CHECK (requester_id <> addressee_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS friendships_pair_unique
  ON public.friendships (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  );

CREATE TABLE IF NOT EXISTS public.crews (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  name text NOT NULL,
  description text,
  region text,
  color_hex text,
  is_public boolean NOT NULL DEFAULT true,
  creator_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX IF NOT EXISTS crews_public_search_idx
  ON public.crews (is_public, deleted_at, region, created_at DESC);

CREATE TABLE IF NOT EXISTS public.crew_members (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  crew_id uuid NOT NULL REFERENCES public.crews(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  is_default_contribution boolean NOT NULL DEFAULT false,
  last_contributed_at timestamptz,
  left_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS crew_members_crew_user_key
  ON public.crew_members (crew_id, user_id);

CREATE INDEX IF NOT EXISTS crew_members_user_active_idx
  ON public.crew_members (user_id, left_at, is_default_contribution DESC);

CREATE UNIQUE INDEX IF NOT EXISTS crew_members_one_active_default_per_user_idx
  ON public.crew_members (user_id)
  WHERE left_at IS NULL AND is_default_contribution = true;

CREATE TABLE IF NOT EXISTS public.crew_seasons (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  season_type text NOT NULL CHECK (season_type IN ('week', 'month')),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed'))
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.crew_seasons'::regclass
      AND conname = 'crew_seasons_valid_window'
  ) THEN
    ALTER TABLE public.crew_seasons
      ADD CONSTRAINT crew_seasons_valid_window CHECK (ends_at > starts_at);
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS crew_seasons_window_key
  ON public.crew_seasons (season_type, starts_at, ends_at);

CREATE TABLE IF NOT EXISTS public.run_crew_contributions (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  run_id bigint NOT NULL REFERENCES public.runs(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  crew_id uuid NOT NULL REFERENCES public.crews(id) ON DELETE CASCADE,
  contribution_area_m2 double precision NOT NULL DEFAULT 0,
  contribution_score double precision NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS run_crew_contributions_run_id_key
  ON public.run_crew_contributions (run_id);

CREATE INDEX IF NOT EXISTS run_crew_contributions_crew_created_idx
  ON public.run_crew_contributions (crew_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.enforce_run_crew_contribution_integrity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  run_owner_id uuid;
  run_started_at timestamp without time zone;
BEGIN
  SELECT r.user_id, r.started_at
  INTO run_owner_id, run_started_at
  FROM public.runs r
  WHERE r.id = NEW.run_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'run_crew_contributions.run_id % does not reference an existing run', NEW.run_id
      USING ERRCODE = '23503';
  END IF;

  IF run_owner_id IS NULL THEN
    RAISE EXCEPTION 'run_crew_contributions.run_id % references a run without user_id', NEW.run_id
      USING ERRCODE = '23514';
  END IF;

  IF NEW.user_id IS NOT NULL AND NEW.user_id <> run_owner_id THEN
    RAISE EXCEPTION 'run_crew_contributions.user_id must match runs.user_id'
      USING ERRCODE = '23514';
  END IF;

  NEW.user_id := run_owner_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.crew_members cm
    WHERE cm.crew_id = NEW.crew_id
      AND cm.user_id = run_owner_id
      AND cm.left_at IS NULL
      AND cm.joined_at <= run_started_at
  ) THEN
    RAISE EXCEPTION 'run user must be an active crew member at run start'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.enforce_run_crew_contribution_integrity() OWNER TO "postgres";

DROP TRIGGER IF EXISTS run_crew_contributions_enforce_integrity ON public.run_crew_contributions;
CREATE TRIGGER run_crew_contributions_enforce_integrity
  BEFORE INSERT OR UPDATE ON public.run_crew_contributions
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_run_crew_contribution_integrity();

COMMENT ON TABLE public.friendships IS
  'Social friend relationships. Mutations are controlled by service-role Edge Functions.';
COMMENT ON TABLE public.crews IS
  'Public crew directory. Mutations are controlled by service-role Edge Functions.';
COMMENT ON TABLE public.crew_members IS
  'Crew membership state. Mutations are controlled by service-role Edge Functions.';
COMMENT ON TABLE public.crew_seasons IS
  'Weekly and monthly crew competition windows. Mutations are controlled by service-role Edge Functions.';
COMMENT ON TABLE public.run_crew_contributions IS
  'Per-run crew contribution records. Mutations are controlled by service-role Edge Functions.';

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crew_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crew_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.run_crew_contributions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friendships_select_participant" ON public.friendships;
CREATE POLICY "friendships_select_participant"
  ON public.friendships
  FOR SELECT
  TO authenticated
  USING (
    requester_id = (SELECT auth.uid())
    OR addressee_id = (SELECT auth.uid())
  );

DROP POLICY IF EXISTS "crews_select_public_or_member" ON public.crews;
DROP POLICY IF EXISTS "crews_select_public_or_creator" ON public.crews;
CREATE POLICY "crews_select_public_or_creator"
  ON public.crews
  FOR SELECT
  TO authenticated
  USING (
    (is_public = true AND deleted_at IS NULL)
    OR creator_id = (SELECT auth.uid())
  );

DROP POLICY IF EXISTS "crew_members_select_relevant" ON public.crew_members;
CREATE POLICY "crew_members_select_relevant"
  ON public.crew_members
  FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.crews c
      WHERE c.id = crew_members.crew_id
        AND c.is_public = true
        AND c.deleted_at IS NULL
        AND crew_members.left_at IS NULL
    )
  );

DROP POLICY IF EXISTS "crew_seasons_select_authenticated" ON public.crew_seasons;
CREATE POLICY "crew_seasons_select_authenticated"
  ON public.crew_seasons
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "run_crew_contributions_select_relevant" ON public.run_crew_contributions;
CREATE POLICY "run_crew_contributions_select_relevant"
  ON public.run_crew_contributions
  FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.crew_members cm
      WHERE cm.crew_id = run_crew_contributions.crew_id
        AND cm.user_id = (SELECT auth.uid())
        AND cm.left_at IS NULL
    )
  );
