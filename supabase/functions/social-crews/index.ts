import { createClient } from "npm:@supabase/supabase-js@2.26.0";
import {
  aggregateCrewMetrics,
  type CrewSort,
  getSeasonBounds,
  nextDateKey,
  parseAnchorDate,
  parseCrewSort,
  parseSeasonType,
  round2,
  type SeasonType,
  sortCrewSummaries,
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

type ContributionRow = {
  crew_id: string;
  user_id?: string;
  contribution_score: number | null;
  contribution_area_m2: number | null;
  created_at?: string | null;
};

type ProfileRow = {
  user_id: string;
  nick_name: string | null;
  color_hex: string | null;
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

function parseLimit(value: string | null): number {
  const parsed = Number(value ?? "");
  if (!Number.isFinite(parsed) || parsed <= 0) return 20;
  return Math.min(Math.floor(parsed), 50);
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
    String(record.details ?? "").includes("crew_members_crew_id_user_id_key") ||
    String(record.message ?? "").includes("crew_members_crew_id_user_id_key");
}

function latestIso(a: string | null, b: string | null): string | null {
  if (!a) return b;
  if (!b) return a;
  return Date.parse(b) > Date.parse(a) ? b : a;
}

async function requireAuthenticatedUser(req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice("Bearer ".length).trim()
    : "";
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
  crews: CrewRow[],
  bounds: { from: string; to: string },
): Promise<{ summaries: InternalCrewSummary[] } | { response: Response }> {
  if (crews.length === 0) return { summaries: [] };

  const crewIds = crews.map((crew) => crew.id);
  const { data: memberRows, error: memberError } = await supabase
    .from("crew_members")
    .select(
      "id,crew_id,user_id,joined_at,is_default_contribution,last_contributed_at,left_at",
    )
    .in("crew_id", crewIds)
    .is("left_at", null);

  if (memberError) {
    return {
      response: json(
        { error: "Failed to fetch crew members", details: memberError.message },
        { status: 500 },
      ),
    };
  }

  const seasonFrom = startOfDayKst(bounds.from);
  const seasonTo = startOfDayKst(nextDateKey(bounds.to));
  const { data: seasonRows, error: seasonError } = await supabase
    .from("run_crew_contributions")
    .select("crew_id,contribution_score,contribution_area_m2")
    .in("crew_id", crewIds)
    .gte("created_at", seasonFrom)
    .lt("created_at", seasonTo);

  if (seasonError) {
    return {
      response: json(
        {
          error: "Failed to fetch season contributions",
          details: seasonError.message,
        },
        { status: 500 },
      ),
    };
  }

  const { data: allRows, error: allError } = await supabase
    .from("run_crew_contributions")
    .select("crew_id,contribution_score,contribution_area_m2,created_at")
    .in("crew_id", crewIds);

  if (allError) {
    return {
      response: json(
        {
          error: "Failed to fetch cumulative contributions",
          details: allError.message,
        },
        { status: 500 },
      ),
    };
  }

  const activeMembers = (memberRows ?? []) as CrewMemberRow[];
  const memberCounts = new Map<string, number>();
  const userMemberships = new Map<string, CrewMemberRow>();
  const latestActivity = new Map<string, string | null>();

  for (const member of activeMembers) {
    memberCounts.set(
      member.crew_id,
      (memberCounts.get(member.crew_id) ?? 0) + 1,
    );
    latestActivity.set(
      member.crew_id,
      latestIso(
        latestActivity.get(member.crew_id) ?? null,
        member.last_contributed_at,
      ),
    );
    if (member.user_id === userId) {
      userMemberships.set(member.crew_id, member);
    }
  }

  const typedAllRows = (allRows ?? []) as ContributionRow[];
  for (const row of typedAllRows) {
    latestActivity.set(
      row.crew_id,
      latestIso(
        latestActivity.get(row.crew_id) ?? null,
        row.created_at ?? null,
      ),
    );
  }

  const seasonMetrics = aggregateCrewMetrics(
    (seasonRows ?? []) as ContributionRow[],
  );
  const cumulativeMetrics = aggregateCrewMetrics(typedAllRows);

  return {
    summaries: crews.map((crew) => {
      const membership = userMemberships.get(crew.id);
      return {
        id: crew.id,
        name: crew.name,
        description: crew.description,
        region: crew.region,
        color_hex: crew.color_hex,
        member_count: memberCounts.get(crew.id) ?? 0,
        season_score: seasonMetrics.get(crew.id)?.finalScore ?? 0,
        cumulative_area_m2: cumulativeMetrics.get(crew.id)?.areaM2 ?? 0,
        is_joined: Boolean(membership),
        is_default_contribution: membership?.is_default_contribution ?? false,
        created_at: crew.created_at,
        last_contributed_at: latestActivity.get(crew.id) ?? null,
      };
    }),
  };
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
    [crewResult.crew],
    bounds,
  );
  if ("response" in summariesResult) return summariesResult;
  return { crew: stripInternal(summariesResult.summaries[0]) };
}

async function fetchMemberContributions(
  supabase: SupabaseClient,
  crewId: string,
  bounds: { from: string; to: string },
): Promise<{ members: CrewMemberContribution[] } | { response: Response }> {
  const { data: memberRows, error: memberError } = await supabase
    .from("crew_members")
    .select(
      "id,crew_id,user_id,joined_at,is_default_contribution,last_contributed_at,left_at",
    )
    .eq("crew_id", crewId)
    .is("left_at", null);

  if (memberError) {
    return {
      response: json(
        { error: "Failed to fetch crew members", details: memberError.message },
        { status: 500 },
      ),
    };
  }

  const activeMembers = (memberRows ?? []) as CrewMemberRow[];
  const userIds = [...new Set(activeMembers.map((member) => member.user_id))];
  const { data: profiles, error: profileError } = userIds.length > 0
    ? await supabase
      .from("profiles")
      .select("user_id,nick_name,color_hex")
      .in("user_id", userIds)
    : { data: [], error: null };

  if (profileError) {
    return {
      response: json(
        {
          error: "Failed to fetch crew member profiles",
          details: profileError.message,
        },
        { status: 500 },
      ),
    };
  }

  const seasonFrom = startOfDayKst(bounds.from);
  const seasonTo = startOfDayKst(nextDateKey(bounds.to));
  const { data: contributionRows, error: contributionError } = await supabase
    .from("run_crew_contributions")
    .select("user_id,crew_id,contribution_score,contribution_area_m2")
    .eq("crew_id", crewId)
    .gte("created_at", seasonFrom)
    .lt("created_at", seasonTo);

  if (contributionError) {
    return {
      response: json(
        {
          error: "Failed to fetch member contributions",
          details: contributionError.message,
        },
        { status: 500 },
      ),
    };
  }

  const profilesById = new Map(
    ((profiles ?? []) as ProfileRow[]).map((
      profile,
    ) => [profile.user_id, profile]),
  );
  const scoreByUser = new Map<string, { score: number; area: number }>();
  for (const row of (contributionRows ?? []) as ContributionRow[]) {
    if (!row.user_id) continue;
    const current = scoreByUser.get(row.user_id) ?? { score: 0, area: 0 };
    const score = Number(row.contribution_score ?? 0);
    const area = Number(row.contribution_area_m2 ?? 0);
    scoreByUser.set(row.user_id, {
      score: current.score + (Number.isFinite(score) ? score : 0),
      area: current.area + (Number.isFinite(area) ? area : 0),
    });
  }

  const ranked = activeMembers
    .map((member) => {
      const profile = profilesById.get(member.user_id);
      const metric = scoreByUser.get(member.user_id) ?? { score: 0, area: 0 };
      return {
        user_id: member.user_id,
        nick_name: profile?.nick_name ?? null,
        color_hex: profile?.color_hex ?? null,
        contribution_score: round2(metric.score),
        contribution_area_m2: round2(metric.area),
        display_rank: 1,
      };
    })
    .sort((a, b) => {
      if (b.contribution_score !== a.contribution_score) {
        return b.contribution_score - a.contribution_score;
      }
      if (b.contribution_area_m2 !== a.contribution_area_m2) {
        return b.contribution_area_m2 - a.contribution_area_m2;
      }
      return a.user_id.localeCompare(b.user_id);
    });

  for (const row of ranked) {
    row.display_rank = 1 +
      ranked.filter((other) =>
        other.contribution_score > row.contribution_score
      )
        .length;
  }

  return { members: ranked };
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
        const q = (url.searchParams.get("q") ?? "").trim().toLowerCase();
        const region = (url.searchParams.get("region") ?? "").trim()
          .toLowerCase();
        const sort = parseCrewSort(url.searchParams.get("sort"));
        const limit = parseLimit(url.searchParams.get("limit"));
        const { bounds } = currentSeason();

        const { data, error } = await supabase
          .from("crews")
          .select(
            "id,name,description,region,color_hex,is_public,created_at,deleted_at",
          )
          .eq("is_public", true)
          .is("deleted_at", null);

        if (error) {
          return json(
            { error: "Failed to search crews", details: error.message },
            { status: 500 },
          );
        }

        const crews = ((data ?? []) as CrewRow[]).filter((crew) => {
          const matchesQ = q.length === 0 ||
            crew.name.toLowerCase().includes(q) ||
            (crew.region ?? "").toLowerCase().includes(q);
          const matchesRegion = region.length === 0 ||
            (crew.region ?? "").toLowerCase().includes(region);
          return matchesQ && matchesRegion;
        });

        const summariesResult = await fetchCrewSummaries(
          supabase,
          userId,
          crews,
          bounds,
        );
        if ("response" in summariesResult) return summariesResult.response;

        const sorted = sortCrewSummaries(summariesResult.summaries, sort)
          .slice(0, limit)
          .map(stripInternal);

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
        const { data: crews, error: crewError } = crewIds.length > 0
          ? await supabase
            .from("crews")
            .select(
              "id,name,description,region,color_hex,is_public,created_at,deleted_at",
            )
            .in("id", crewIds)
            .eq("is_public", true)
            .is("deleted_at", null)
          : { data: [], error: null };

        if (crewError) {
          return json(
            {
              error: "Failed to fetch crew details",
              details: crewError.message,
            },
            { status: 500 },
          );
        }

        const summariesResult = await fetchCrewSummaries(
          supabase,
          userId,
          (crews ?? []) as CrewRow[],
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
          [crewResult.crew],
          season.bounds,
        );
        if ("response" in summaryResult) return summaryResult.response;

        const membersResult = await fetchMemberContributions(
          supabase,
          crewId,
          season.bounds,
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
          members: membersResult.members,
        });
      }

      if (mode === "ranking") {
        const season = parseSeasonParams(url);
        if ("error" in season) {
          return json({ error: season.error }, { status: season.status });
        }

        const { data, error } = await supabase
          .from("crews")
          .select(
            "id,name,description,region,color_hex,is_public,created_at,deleted_at",
          )
          .eq("is_public", true)
          .is("deleted_at", null);

        if (error) {
          return json(
            { error: "Failed to fetch crew ranking", details: error.message },
            { status: 500 },
          );
        }

        const summariesResult = await fetchCrewSummaries(
          supabase,
          userId,
          (data ?? []) as CrewRow[],
          season.bounds,
        );
        if ("response" in summariesResult) return summariesResult.response;

        const ranked = sortCrewSummaries(
          summariesResult.summaries,
          "score" satisfies CrewSort,
        ).map((summary) => ({ ...stripInternal(summary), display_rank: 1 }));

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
        return json({ error: "Active crew membership not found" }, {
          status: 404,
        });
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
        .single();

      if (error) {
        return json(
          { error: "Failed to leave crew", details: error.message },
          { status: 500 },
        );
      }

      return json({ status: "left", membership: data });
    }

    if (action === "set_default") {
      const active = await fetchActiveMembership(supabase, userId, crewId);
      if ("response" in active) return active.response;
      if (!active.membership) {
        return json({ error: "Active crew membership not found" }, {
          status: 404,
        });
      }

      const { error: clearError } = await supabase
        .from("crew_members")
        .update({ is_default_contribution: false })
        .eq("user_id", userId)
        .is("left_at", null);

      if (clearError) {
        return json(
          {
            error: "Failed to clear default crew",
            details: clearError.message,
          },
          { status: 500 },
        );
      }

      const { data: updated, error: updateError } = await supabase
        .from("crew_members")
        .update({ is_default_contribution: true })
        .eq("id", active.membership.id)
        .is("left_at", null)
        .select(
          "id,crew_id,user_id,joined_at,is_default_contribution,last_contributed_at,left_at",
        )
        .single();

      if (updateError) {
        return json(
          {
            error: "Failed to set default crew",
            details: updateError.message,
          },
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
