import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

type RangeType = "day" | "week" | "month" | "year" | "all";

type ProfileRow = {
  user_id: string;
  nick_name: string | null;
  color_hex: string | null;
  total_points?: number | null;
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

function parseRangeType(value: string | null): RangeType {
  const raw = (value ?? "").toLowerCase();
  if (
    raw === "day" ||
    raw === "week" ||
    raw === "month" ||
    raw === "year" ||
    raw === "all"
  ) {
    return raw;
  }
  return "all";
}

function parseAnchorDate(value: string | null): Date {
  if (!value) return new Date();
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (m) {
    const y = Number(m[1]);
    const mo = Number(m[2]);
    const d = Number(m[3]);
    if (
      Number.isFinite(y) &&
      Number.isFinite(mo) &&
      Number.isFinite(d)
    ) {
      // 날짜만 다루는 anchor이므로 timezone 변환으로 전날로 밀리지 않게 고정
      return new Date(y, mo - 1, d, 12, 0, 0, 0);
    }
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return new Date();
  return parsed;
}

function kstDateString(date: Date): string {
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const d = String(kst.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function startOfWeekMonday(date: Date): Date {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const weekday = d.getDay() === 0 ? 7 : d.getDay();
  return addDays(d, -(weekday - 1));
}

function getRangeBounds(rangeType: RangeType, anchor: Date): {
  from: string;
  to: string;
} | null {
  if (rangeType === "all") return null;

  const day = new Date(
    anchor.getFullYear(),
    anchor.getMonth(),
    anchor.getDate(),
  );
  if (rangeType === "day") {
    const key = kstDateString(day);
    return { from: key, to: key };
  }

  if (rangeType === "week") {
    const from = startOfWeekMonday(day);
    const to = addDays(from, 6);
    return { from: kstDateString(from), to: kstDateString(to) };
  }

  if (rangeType === "month") {
    const from = new Date(day.getFullYear(), day.getMonth(), 1);
    const to = new Date(day.getFullYear(), day.getMonth() + 1, 0);
    return { from: kstDateString(from), to: kstDateString(to) };
  }

  const from = new Date(day.getFullYear(), 0, 1);
  const to = new Date(day.getFullYear(), 11, 31);
  return { from: kstDateString(from), to: kstDateString(to) };
}

function startOfDayKst(dateKey: string) {
  return `${dateKey}T00:00:00+09:00`;
}

function endOfDayKst(dateKey: string) {
  return `${dateKey}T23:59:59.999+09:00`;
}

function aggregateScores(
  rows: Array<{ user_id: string; total_points: number | null }>,
): Map<string, number> {
  const map = new Map<string, number>();
  for (const row of rows) {
    const userId = row.user_id;
    const score = Number(row.total_points ?? 0);
    if (!Number.isFinite(score)) continue;
    map.set(userId, (map.get(userId) ?? 0) + score);
  }
  return map;
}

function aggregateHistoryScores(
  rows: Array<{ user_id: string; points_delta: number | null }>,
): Map<string, number> {
  const map = new Map<string, number>();
  for (const row of rows) {
    const userId = row.user_id;
    const score = Number(row.points_delta ?? 0);
    if (!Number.isFinite(score)) continue;
    map.set(userId, (map.get(userId) ?? 0) + score);
  }
  return map;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "GET") {
    return json({ error: "Method not allowed" }, { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(
      { error: "Missing required Supabase environment variables" },
      { status: 500 },
    );
  }

  const requestUrl = new URL(req.url);
  const mode = (requestUrl.searchParams.get("mode") ?? "top").toLowerCase();
  const rangeType = parseRangeType(requestUrl.searchParams.get("range_type"));
  const anchorDate = parseAnchorDate(
    requestUrl.searchParams.get("anchor_date"),
  );
  const bounds = getRangeBounds(rangeType, anchorDate);

  const authHeader = req.headers.get("Authorization");
  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: authHeader ? { headers: { Authorization: authHeader } } : undefined,
  });

  const {
    data: { user },
  } = await authClient.auth.getUser();

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let scoreboard: Array<{
    user_id: string;
    nick_name: string;
    color_hex: string;
    total_points: number;
  }> = [];

  // 전체 탭은 profiles.total_points를 직접 사용
  if (rangeType === "all") {
    const { data: profiles, error: profileError } = await adminClient
      .from("profiles")
      .select("user_id,nick_name,color_hex,total_points");

    if (profileError) {
      return json(
        {
          error: "Failed to fetch profiles total points",
          details: profileError.message,
        },
        { status: 500 },
      );
    }

    scoreboard = ((profiles ?? []) as ProfileRow[])
      .map((row) => ({
        user_id: row.user_id,
        nick_name: row.nick_name ?? "익명",
        color_hex: row.color_hex ?? "#448AFF",
        total_points: Number((row.total_points ?? 0).toFixed(2)),
      }))
      .sort((a, b) => {
        if (b.total_points !== a.total_points) {
          return b.total_points - a.total_points;
        }
        return a.user_id.localeCompare(b.user_id);
      });
  } else {
    let dailyQuery = adminClient.from("user_point_daily").select(
      "user_id,total_points",
    );
    if (bounds) {
      dailyQuery = dailyQuery
        .gte("day_kst", bounds.from)
        .lte("day_kst", bounds.to);
    }

    const { data: dailyRows, error: dailyError } = await dailyQuery;
    if (dailyError) {
      return json(
        { error: "Failed to fetch daily scores", details: dailyError.message },
        { status: 500 },
      );
    }

    let scoreMap = aggregateScores(
      (dailyRows ?? []) as Array<
        { user_id: string; total_points: number | null }
      >,
    );

    // daily 집계가 비어있으면 point_history에서 직접 합산 (백필 이전 대비)
    if (scoreMap.size === 0) {
      let historyQuery = adminClient
        .from("point_history")
        .select("user_id,points_delta");
      if (bounds) {
        historyQuery = historyQuery
          .gte("created_at", startOfDayKst(bounds.from))
          .lte("created_at", endOfDayKst(bounds.to));
      }
      const { data: historyRows, error: historyError } = await historyQuery;
      if (historyError) {
        return json(
          {
            error: "Failed to fetch point history",
            details: historyError.message,
          },
          { status: 500 },
        );
      }
      scoreMap = aggregateHistoryScores(
        (historyRows ?? []) as Array<
          { user_id: string; points_delta: number | null }
        >,
      );
    }

    const userIds = [...scoreMap.keys()];
    if (userIds.length > 0) {
      const { data: profiles, error: profileError } = await adminClient
        .from("profiles")
        .select("user_id,nick_name,color_hex")
        .in("user_id", userIds);

      if (profileError) {
        return json(
          { error: "Failed to fetch profiles", details: profileError.message },
          { status: 500 },
        );
      }

      const profileMap = new Map<string, ProfileRow>();
      for (const row of (profiles ?? []) as ProfileRow[]) {
        profileMap.set(row.user_id, row);
      }

      scoreboard = userIds
        .map((userId) => {
          const profile = profileMap.get(userId);
          return {
            user_id: userId,
            nick_name: profile?.nick_name ?? "익명",
            color_hex: profile?.color_hex ?? "#448AFF",
            total_points: Number((scoreMap.get(userId) ?? 0).toFixed(2)),
          };
        })
        .sort((a, b) => {
          if (b.total_points !== a.total_points) {
            return b.total_points - a.total_points;
          }
          return a.user_id.localeCompare(b.user_id);
        });
    }
  }

  if (scoreboard.length === 0) {
    if (mode === "context") {
      return json({
        mode: "context",
        user: null,
        above: [],
        self: null,
        below: [],
      });
    }
    return json({ mode: "top", results: [] });
  }

  const rankOf = (userId: string) => {
    const score = scoreboard.find((v) => v.user_id === userId)?.total_points ??
      0;
    let rank = 1;
    for (const row of scoreboard) {
      if (row.total_points > score) rank++;
    }
    return rank;
  };

  if (mode === "top") {
    return json({
      mode: "top",
      range_type: rangeType,
      anchor_date: bounds?.from ?? null,
      results: scoreboard.slice(0, 100).map((row) => ({
        ...row,
        rank: rankOf(row.user_id),
      })),
    });
  }

  if (!user) {
    return json({ error: "Unauthorized" }, { status: 401 });
  }

  const requestedUserId = requestUrl.searchParams.get("user_id");
  if (requestedUserId && requestedUserId !== user.id) {
    return json({ error: "Forbidden" }, { status: 403 });
  }

  const selfIndex = scoreboard.findIndex((v) => v.user_id === user.id);
  const selfScore = selfIndex >= 0 ? scoreboard[selfIndex] : {
    user_id: user.id,
    nick_name: "나",
    color_hex: "#448AFF",
    total_points: 0,
  };
  const selfRank = rankOf(user.id);

  const withRank = scoreboard.map((row) => ({
    ...row,
    rank: rankOf(row.user_id),
  }));
  const safeSelfIndex = withRank.findIndex((v) => v.user_id === user.id);

  const above = safeSelfIndex > 0
    ? withRank.slice(Math.max(0, safeSelfIndex - 3), safeSelfIndex)
    : [];
  const below = safeSelfIndex >= 0
    ? withRank.slice(safeSelfIndex + 1, safeSelfIndex + 4)
    : [];

  return json({
    mode: "context",
    range_type: rangeType,
    anchor_date: bounds?.from ?? null,
    user: {
      user_id: selfScore.user_id,
      rank: selfRank,
      total_points: selfScore.total_points,
    },
    above,
    self: {
      ...selfScore,
      rank: selfRank,
      is_self: true,
    },
    below,
  });
});
