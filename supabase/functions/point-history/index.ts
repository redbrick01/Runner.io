import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

type RangeType = "day" | "week" | "month" | "year" | "all";

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
    if (Number.isFinite(y) && Number.isFinite(mo) && Number.isFinite(d)) {
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
  toExclusive: string;
  anchorDate: string;
} | null {
  if (rangeType === "all") return null;

  const day = new Date(
    anchor.getFullYear(),
    anchor.getMonth(),
    anchor.getDate(),
  );

  if (rangeType === "day") {
    const from = kstDateString(day);
    const toExclusive = kstDateString(addDays(day, 1));
    return { from, toExclusive, anchorDate: from };
  }

  if (rangeType === "week") {
    const fromDate = startOfWeekMonday(day);
    const toExclusiveDate = addDays(fromDate, 7);
    return {
      from: kstDateString(fromDate),
      toExclusive: kstDateString(toExclusiveDate),
      anchorDate: kstDateString(fromDate),
    };
  }

  if (rangeType === "month") {
    const fromDate = new Date(day.getFullYear(), day.getMonth(), 1);
    const toExclusiveDate = new Date(day.getFullYear(), day.getMonth() + 1, 1);
    return {
      from: kstDateString(fromDate),
      toExclusive: kstDateString(toExclusiveDate),
      anchorDate: kstDateString(fromDate),
    };
  }

  const fromDate = new Date(day.getFullYear(), 0, 1);
  const toExclusiveDate = new Date(day.getFullYear() + 1, 0, 1);
  return {
    from: kstDateString(fromDate),
    toExclusive: kstDateString(toExclusiveDate),
    anchorDate: kstDateString(fromDate),
  };
}

function startOfDayKst(dateKey: string) {
  return `${dateKey}T00:00:00+09:00`;
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
  const rangeType = parseRangeType(requestUrl.searchParams.get("range_type"));
  const anchorDate = parseAnchorDate(
    requestUrl.searchParams.get("anchor_date"),
  );
  const bounds = getRangeBounds(rangeType, anchorDate);

  const limitParam = Number.parseInt(
    requestUrl.searchParams.get("limit") ?? "100",
    10,
  );
  const offsetParam = Number.parseInt(
    requestUrl.searchParams.get("offset") ?? "0",
    10,
  );
  const limit = Number.isFinite(limitParam)
    ? Math.min(Math.max(limitParam, 1), 2000)
    : 100;
  const offset = Number.isFinite(offsetParam) ? Math.max(offsetParam, 0) : 0;

  const authHeader = req.headers.get("Authorization");
  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: authHeader ? { headers: { Authorization: authHeader } } : undefined,
  });

  const {
    data: { user },
  } = await authClient.auth.getUser();
  if (!user) {
    return json({ error: "Unauthorized" }, { status: 401 });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let query = adminClient
    .from("point_history")
    .select("id,event_type,points_delta,created_at")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    // 1개 더 조회해서 has_more 계산
    .range(offset, offset + limit);

  if (bounds) {
    query = query
      .gte("created_at", startOfDayKst(bounds.from))
      .lt("created_at", startOfDayKst(bounds.toExclusive));
  }

  const { data, error } = await query;
  if (error) {
    return json(
      { error: "Failed to fetch point history", details: error.message },
      { status: 500 },
    );
  }

  const rows = (data ?? []) as Array<{
    id: string | number;
    event_type: string;
    points_delta: number | null;
    created_at: string;
  }>;

  const hasMore = rows.length > limit;
  const items = hasMore ? rows.slice(0, limit) : rows;

  return json({
    items,
    pagination: {
      limit,
      offset,
      has_more: hasMore,
      next_offset: hasMore ? offset + limit : null,
    },
    range_type: rangeType,
    anchor_date: bounds?.anchorDate ?? null,
  });
});
