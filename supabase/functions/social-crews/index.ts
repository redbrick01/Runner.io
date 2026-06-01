import { createClient } from "npm:@supabase/supabase-js@2.26.0";
import {
  getSeasonBounds,
  nextDateKey,
  parseAnchorDate,
  parseBearerToken,
  parseCrewSort,
  parseMemberLimit,
  parseSearchLimit,
  parseSeasonType,
  type SeasonType,
  startOfDayKst,
} from "./helpers.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

type SupabaseClient = ReturnType<typeof createClient>;
type JsonRecord = Record<string, unknown>;

type CrewRow = {
  id: string;
  name: string;
  description: string | null;
  region: string | null;
  color_hex: string | null;
  is_public: boolean;
  created_at: string;
  deleted_at: string | null;
};

type CrewMemberRow = {
  id: string;
  crew_id: string;
  user_id: string;
  joined_at: string;
  is_default_contribution: boolean;
  last_contributed_at: string | null;
  left_at: string | null;
};

type CrewSummary = {
  id: string;
  name: string;
  description: string | null;
  region: string | null;
  color_hex: string | null;
  member_count: number;
  season_score: number;
  cumulative_area_m2: number;
  is_joined: boolean;
  is_default_contribution: boolean;
};

type InternalCrewSummary = CrewSummary & {
  created_at: string;
  last_contributed_at: string | null;
};

type CrewMemberContribution = {
  user_id: string;
  nick_name: string | null;
  color_hex: string | null;
  contribution_score: number;
  contribution_area_m2: number;
  display_rank: number;
};

function json(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
      ...(init.headers ?? {}),
    },
  });
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function stripInternal(summary: InternalCrewSummary): CrewSummary {
  return {
    id: summary.id,
    name: summary.name,
    description: summary.description,
    region: summary.region,
    color_hex: summary.color_hex,
    member_count: summary.member_count,
    season_score: summary.season_score,
    cumulative_area_m2: summary.cumulative_area_m2,
    is_joined: summary.is_joined,
    is_default_contribution: summary.is_default_contribution,
  };
}

function isUniqueViolation(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const record = error as Record<string, unknown>;
  return record.code === "23505" ||
    String(record.details ?? "").includes("crews_active_name_key") ||
    String(record.message ?? "").includes("crews_active_name_key") ||
    String(record.details ?? "").includes("crew_members_crew_id_user_id_key") ||
    String(record.message ?? "").includes("crew_members_crew_id_user_id_key");
}

function normalizeOptionalText(
  value: unknown,
  maxLength: number,
): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  return trimmed.slice(0, maxLength);
}

function normalizeCrewName(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (trimmed.length < 2 || trimmed.length > 24) return null;
  return trimmed;
}

function normalizeColorHex(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!/^#[0-9a-fA-F]{6}$/.test(trimmed)) return null;
  return trimmed.toUpperCase();
}

async function requireAuthenticatedUser(req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = parseBearerToken(authHeader, SUPABASE_ANON_KEY);
  if (!token || token === SUPABASE_ANON_KEY) {
    return { error: "Missing access token", status: 401 };
  }

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    return {
      error: "Missing required Supabase environment variables",
      status: 500,
    };
  }

  const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await authClient.auth.getUser(token);
  if (error || !data.user) {
    return { error: "Invalid access token", status: 401 };
  }

  return { userId: data.user.id };
}

function adminClient() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function currentSeason() {
  const anchor = parseAnchorDate(null);
  if (!anchor.ok) {
    throw new Error("Failed to parse current KST date");
  }
  const seasonType: SeasonType = "week";
  const bounds = getSeasonBounds(seasonType, anchor.date);
  return { seasonType, anchorDate: anchor.submitted, bounds };
}

function parseSeasonParams(url: URL) {
  const seasonType = parseSeasonType(url.searchParams.get("season_type"));
  if (seasonType === "invalid") {
    return { error: "season_type must be week or month", status: 400 };
  }

  const anchor = parseAnchorDate(url.searchParams.get("anchor_date"));
  if (!anchor.ok) {
    return { error: "anchor_date must be YYYY-MM-DD", status: 400 };
  }

  return {
    seasonType,
    anchorDate: anchor.submitted,
    bounds: getSeasonBounds(seasonType, anchor.date),
  };
}

async function fetchPublicCrew(
  supabase: SupabaseClient,
  crewId: string,
): Promise<{ crew: CrewRow | null } | { response: Response }> {
  const { data, error } = await supabase
    .from("crews")
    .select(
      "id,name,description,region,color_hex,is_public,created_at,deleted_at",
    )
    .eq("id", crewId)
    .eq("is_public", true)
    .is("deleted_at", null)
    .maybeSingle();

  if (error) {
    return {
      response: json(
        { error: "Failed to fetch crew", details: error.message },
        { status: 500 },
      ),
    };
  }

  return { crew: data as CrewRow | null };
}

async function fetchCrewSummaries(
  supabase: SupabaseClient,
  userId: string,
  crewIds: string[],
  bounds: { from: string; to: string },
): Promise<{ summaries: InternalCrewSummary[] } | { response: Response }> {
  if (crewIds.length === 0) return { summaries: [] };

  const { data, error } = await supabase.rpc("social_crew_summaries_by_ids", {
    p_user_id: userId,
    p_crew_ids: crewIds,
    p_season_from: startOfDayKst(bounds.from),
    p_season_to_exclusive: startOfDayKst(nextDateKey(bounds.to)),
  });

  if (error) {
    return {
      response: json(
        { error: "Failed to fetch crew summaries", details: error.message },
        { status: 500 },
      ),
    };
  }

  return { summaries: (data ?? []) as InternalCrewSummary[] };
}

async function searchCrewSummaries(
  supabase: SupabaseClient,
  userId: string,
  params: {
    q: string;
    region: string;
    sort: string;
    limit: number;
    bounds: { from: string; to: string };
  },
): Promise<{ summaries: InternalCrewSummary[] } | { response: Response }> {
  const { data, error } = await supabase.rpc("social_crew_summaries", {
    p_user_id: userId,
    p_q: params.q.length > 0 ? params.q : null,
    p_region: params.region.length > 0 ? params.region : null,
    p_sort: params.sort,
    p_limit: params.limit,
    p_season_from: startOfDayKst(params.bounds.from),
    p_season_to_exclusive: startOfDayKst(nextDateKey(params.bounds.to)),
  });

  if (error) {
    return {
      response: json(
        { error: "Failed to fetch crew summaries", details: error.message },
        { status: 500 },
      ),
    };
  }

  return { summaries: (data ?? []) as InternalCrewSummary[] };
}

async function fetchActiveMembership(
  supabase: SupabaseClient,
  userId: string,
  crewId: string,
): Promise<{ membership: CrewMemberRow | null } | { response: Response }> {
  const { data, error } = await supabase
    .from("crew_members")
    .select(
      "id,crew_id,user_id,joined_at,is_default_contribution,last_contributed_at,left_at",
    )
    .eq("crew_id", crewId)
    .eq("user_id", userId)
    .is("left_at", null)
    .maybeSingle();

  if (error) {
    return {
      response: json(
        { error: "Failed to fetch crew membership", details: error.message },
        { status: 500 },
      ),
    };
  }

  return { membership: data as CrewMemberRow | null };
}

async function fetchCrewSummaryById(
  supabase: SupabaseClient,
  userId: string,
  crewId: string,
): Promise<{ crew: CrewSummary | null } | { response: Response }> {
  const crewResult = await fetchPublicCrew(supabase, crewId);
  if ("response" in crewResult) return crewResult;
  if (!crewResult.crew) return { crew: null };

  const { bounds } = currentSeason();
  const summariesResult = await fetchCrewSummaries(
    supabase,
    userId,
    [crewId],
    bounds,
  );
  if ("response" in summariesResult) return summariesResult;
  return { crew: stripInternal(summariesResult.summaries[0]) };
}

async function fetchMemberContributions(
  supabase: SupabaseClient,
  crewId: string,
  bounds: { from: string; to: string },
  limit: number,
): Promise<{ members: CrewMemberContribution[] } | { response: Response }> {
  const { data, error } = await supabase.rpc(
    "social_crew_member_contributions",
    {
      p_crew_id: crewId,
      p_season_from: startOfDayKst(bounds.from),
      p_season_to_exclusive: startOfDayKst(nextDateKey(bounds.to)),
      p_limit: limit,
    },
  );

  if (error) {
    return {
      response: json(
        {
          error: "Failed to fetch member contributions",
          details: error.message,
        },
        { status: 500 },
      ),
    };
  }

  return { members: (data ?? []) as CrewMemberContribution[] };
}

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    if (req.method !== "GET" && req.method !== "POST") {
      return json({ error: "Method not allowed" }, { status: 405 });
    }

    const auth = await requireAuthenticatedUser(req);
    if ("error" in auth) {
      return json({ error: auth.error }, { status: auth.status });
    }

    const supabase = adminClient();
    if (!supabase) {
      return json(
        { error: "Missing required Supabase environment variables" },
        { status: 500 },
      );
    }

    const userId = auth.userId;

    if (req.method === "GET") {
      const url = new URL(req.url);
      const mode = (url.searchParams.get("mode") ?? "search").toLowerCase();

      if (mode === "search") {
        const q = (url.searchParams.get("q") ?? "").trim();
        const region = (url.searchParams.get("region") ?? "").trim();
        const sort = parseCrewSort(url.searchParams.get("sort"));
        const limit = parseSearchLimit(url.searchParams.get("limit"));
        const { bounds } = currentSeason();

        const summariesResult = await searchCrewSummaries(
          supabase,
          userId,
          { q, region, sort, limit, bounds },
        );
        if ("response" in summariesResult) return summariesResult.response;

        const sorted = summariesResult.summaries.map(stripInternal);

        return json({ crews: sorted });
      }

      if (mode === "my") {
        const { bounds } = currentSeason();
        const { data: memberships, error: memberError } = await supabase
          .from("crew_members")
          .select(
            "id,crew_id,user_id,joined_at,is_default_contribution,last_contributed_at,left_at",
          )
          .eq("user_id", userId)
          .is("left_at", null)
          .order("is_default_contribution", { ascending: false })
          .order("last_contributed_at", { ascending: false, nullsFirst: false })
          .order("joined_at", { ascending: false });

        if (memberError) {
          return json(
            { error: "Failed to fetch my crews", details: memberError.message },
            { status: 500 },
          );
        }

        const crewIds = [
          ...new Set(
            ((memberships ?? []) as CrewMemberRow[]).map((member) =>
              member.crew_id
            ),
          ),
        ];
        const summariesResult = await fetchCrewSummaries(
          supabase,
          userId,
          crewIds,
          bounds,
        );
        if ("response" in summariesResult) return summariesResult.response;

        const order = new Map(crewIds.map((id, index) => [id, index]));
        const myCrews = summariesResult.summaries
          .sort((a, b) => (order.get(a.id) ?? 0) - (order.get(b.id) ?? 0))
          .map(stripInternal);

        return json({ crews: myCrews });
      }

      if (mode === "detail") {
        const crewId = (url.searchParams.get("crew_id") ?? "").trim();
        if (!isUuid(crewId)) {
          return json({ error: "Invalid crew_id" }, { status: 400 });
        }

        const season = parseSeasonParams(url);
        if ("error" in season) {
          return json({ error: season.error }, { status: season.status });
        }

        const crewResult = await fetchPublicCrew(supabase, crewId);
        if ("response" in crewResult) return crewResult.response;
        if (!crewResult.crew) {
          return json({ error: "Crew not found" }, { status: 404 });
        }

        const summaryResult = await fetchCrewSummaries(
          supabase,
          userId,
          [crewId],
          season.bounds,
        );
        if ("response" in summaryResult) return summaryResult.response;

        const membersResult = await fetchMemberContributions(
          supabase,
          crewId,
          season.bounds,
          parseMemberLimit(url.searchParams.get("member_limit")),
        );
        if ("response" in membersResult) return membersResult.response;

        return json({
          season: {
            season_type: season.seasonType,
            anchor_date: season.anchorDate,
            from: season.bounds.from,
            to: season.bounds.to,
          },
          crew: stripInternal(summaryResult.summaries[0]),
          can_view_members: true,
          members: membersResult.members,
        });
      }

      if (mode === "ranking") {
        const season = parseSeasonParams(url);
        if ("error" in season) {
          return json({ error: season.error }, { status: season.status });
        }

        const summariesResult = await searchCrewSummaries(
          supabase,
          userId,
          {
            q: "",
            region: "",
            sort: "score",
            limit: parseSearchLimit(url.searchParams.get("limit") ?? "100"),
            bounds: season.bounds,
          },
        );
        if ("response" in summariesResult) return summariesResult.response;

        const ranked = summariesResult.summaries
          .map((summary) => ({ ...stripInternal(summary), display_rank: 1 }));

        for (const row of ranked) {
          row.display_rank = 1 +
            ranked.filter((other) => other.season_score > row.season_score)
              .length;
        }

        return json({
          season: {
            season_type: season.seasonType,
            anchor_date: season.anchorDate,
            from: season.bounds.from,
            to: season.bounds.to,
          },
          crews: ranked,
        });
      }

      return json({ error: "Invalid mode" }, { status: 400 });
    }

    const payload = await req.json().catch(() => null);
    if (!isRecord(payload)) {
      return json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const action = typeof payload.action === "string"
      ? payload.action.toLowerCase()
      : "";
    const crewId = typeof payload.crew_id === "string"
      ? payload.crew_id.trim()
      : "";

    if (action === "create") {
      const name = normalizeCrewName(payload.name);
      if (!name) {
        return json({ error: "name must be 2-24 characters" }, {
          status: 400,
        });
      }

      const colorHex = normalizeColorHex(payload.color_hex) ?? "#448AFF";
      const description = normalizeOptionalText(payload.description, 120);
      const region = normalizeOptionalText(payload.region, 24);

      const duplicate = await supabase
        .from("crews")
        .select("id")
        .ilike("name", name)
        .is("deleted_at", null)
        .limit(1)
        .maybeSingle();

      if (duplicate.error) {
        return json(
          {
            error: "Failed to check crew name",
            details: duplicate.error.message,
          },
          { status: 500 },
        );
      }
      if (duplicate.data) {
        return json({ error: "Crew name already exists" }, { status: 409 });
      }

      const created = await supabase
        .from("crews")
        .insert({
          name,
          description,
          region,
          color_hex: colorHex,
          is_public: true,
          creator_id: userId,
        })
        .select("id")
        .single();

      if (created.error) {
        if (isUniqueViolation(created.error)) {
          return json({ error: "Crew name already exists" }, { status: 409 });
        }

        return json(
          { error: "Failed to create crew", details: created.error.message },
          { status: 500 },
        );
      }

      const now = new Date().toISOString();
      const membership = await supabase
        .from("crew_members")
        .insert({
          crew_id: created.data.id,
          user_id: userId,
          joined_at: now,
          is_default_contribution: false,
        })
        .select("id")
        .single();

      if (membership.error) {
        return json(
          {
            error: "Crew created but failed to join creator",
            details: membership.error.message,
          },
          { status: 500 },
        );
      }

      const { error: defaultError } = await supabase.rpc("set_default_crew", {
        p_user_id: userId,
        p_crew_id: created.data.id,
      });

      if (defaultError) {
        return json(
          {
            error: "Crew created but failed to set default",
            details: defaultError.message,
          },
          { status: 500 },
        );
      }

      const summaryResult = await fetchCrewSummaryById(
        supabase,
        userId,
        created.data.id,
      );
      if ("response" in summaryResult) return summaryResult.response;

      return json({
        status: "created",
        membership_id: membership.data.id,
        crew: summaryResult.crew,
      }, { status: 201 });
    }

    if (!isUuid(crewId)) {
      return json({ error: "Invalid crew_id" }, { status: 400 });
    }

    if (action === "join") {
      const crewResult = await fetchPublicCrew(supabase, crewId);
      if ("response" in crewResult) return crewResult.response;
      if (!crewResult.crew) {
        return json({ error: "Crew unavailable" }, { status: 404 });
      }

      const { data: existing, error: existingError } = await supabase
        .from("crew_members")
        .select(
          "id,crew_id,user_id,joined_at,is_default_contribution,last_contributed_at,left_at",
        )
        .eq("crew_id", crewId)
        .eq("user_id", userId)
        .maybeSingle();

      if (existingError) {
        return json(
          {
            error: "Failed to check crew membership",
            details: existingError.message,
          },
          { status: 500 },
        );
      }

      const existingMembership = existing as CrewMemberRow | null;
      if (existingMembership?.left_at === null) {
        const summaryResult = await fetchCrewSummaryById(
          supabase,
          userId,
          crewId,
        );
        if ("response" in summaryResult) return summaryResult.response;
        return json({
          status: "already_joined",
          membership_id: existingMembership.id,
          crew: summaryResult.crew,
        });
      }

      const now = new Date().toISOString();
      const mutation = existingMembership
        ? await supabase
          .from("crew_members")
          .update({
            joined_at: now,
            left_at: null,
            is_default_contribution: false,
          })
          .eq("id", existingMembership.id)
          .select("id")
          .single()
        : await supabase
          .from("crew_members")
          .insert({
            crew_id: crewId,
            user_id: userId,
            joined_at: now,
            is_default_contribution: false,
          })
          .select("id")
          .single();

      if (mutation.error) {
        if (isUniqueViolation(mutation.error)) {
          const active = await fetchActiveMembership(supabase, userId, crewId);
          if ("response" in active) return active.response;
          if (active.membership) {
            const summaryResult = await fetchCrewSummaryById(
              supabase,
              userId,
              crewId,
            );
            if ("response" in summaryResult) return summaryResult.response;
            return json({
              status: "already_joined",
              membership_id: active.membership.id,
              crew: summaryResult.crew,
            });
          }
        }

        return json(
          { error: "Failed to join crew", details: mutation.error.message },
          { status: 500 },
        );
      }

      const summaryResult = await fetchCrewSummaryById(
        supabase,
        userId,
        crewId,
      );
      if ("response" in summaryResult) return summaryResult.response;
      return json({
        status: "joined",
        membership_id: mutation.data.id,
        crew: summaryResult.crew,
      }, { status: 201 });
    }

    if (action === "leave") {
      const active = await fetchActiveMembership(supabase, userId, crewId);
      if ("response" in active) return active.response;
      if (!active.membership) {
        return json({ status: "already_left", membership: null });
      }

      const { data, error } = await supabase
        .from("crew_members")
        .update({
          left_at: new Date().toISOString(),
          is_default_contribution: false,
        })
        .eq("id", active.membership.id)
        .is("left_at", null)
        .select("id,crew_id,left_at,is_default_contribution")
        .maybeSingle();

      if (error) {
        return json(
          { error: "Failed to leave crew", details: error.message },
          { status: 500 },
        );
      }
      if (!data) {
        return json({ status: "already_left", membership: null });
      }

      return json({ status: "left", membership: data });
    }

    if (action === "set_default") {
      const { data: updated, error: updateError } = await supabase
        .rpc("set_default_crew", {
          p_user_id: userId,
          p_crew_id: crewId,
        })
        .maybeSingle();

      if (updateError) {
        return json(
          {
            error: "Failed to set default crew",
            details: updateError.message,
          },
          { status: 500 },
        );
      }
      if (!updated) {
        return json({ error: "Active crew membership not found" }, {
          status: 404,
        });
      }

      const summaryResult = await fetchCrewSummaryById(
        supabase,
        userId,
        crewId,
      );
      if ("response" in summaryResult) return summaryResult.response;
      return json({
        status: "default_set",
        membership: updated,
        crew: summaryResult.crew,
      });
    }

    return json({ error: "Invalid action" }, { status: 400 });
  } catch (error) {
    console.error(error);
    return json({ error: "Internal server error" }, { status: 500 });
  }
});
