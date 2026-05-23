import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

type RunHistoryItem = {
  id: number;
  started_at: string;
  ended_at: string;
  duration: number;
  distance: number;
  created_at: string;
  user_id: string;
  point: number;
  avg_pace: number | null;
  calories: number | null;
  area: number | null;
  path_geom: string | null;
  loop_geom: string | null;
};

type RunSplitItem = {
  run_id: number;
  split_index: number;
  distance_m: number;
  duration_s: number;
  avg_pace_s_per_km: number | null;
  avg_speed_mps: number | null;
  ascent_m: number | null;
  calories: number | null;
  path_geom: string | null;
};

function json(
  body: unknown,
  init: ResponseInit = {},
) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
      ...(init.headers ?? {}),
    },
  });
}

function badRequest(message: string) {
  return json({ error: message }, { status: 400 });
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
  const authHeader = req.headers.get("Authorization");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(
      { error: "Missing required Supabase environment variables" },
      { status: 500 },
    );
  }

  if (!authHeader) {
    return json({ error: "Missing Authorization header" }, { status: 401 });
  }

  const requestUrl = new URL(req.url);
  const limitParam = Number.parseInt(
    requestUrl.searchParams.get("limit") ?? "50",
    10,
  );
  const offsetParam = Number.parseInt(
    requestUrl.searchParams.get("offset") ?? "0",
    10,
  );

  if (Number.isNaN(limitParam) || Number.isNaN(offsetParam)) {
    return badRequest("limit and offset must be valid integers");
  }

  const limit = Math.min(Math.max(limitParam, 1), 100);
  const offset = Math.max(offsetParam, 0);

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
  });

  const {
    data: { user },
    error: userError,
  } = await authClient.auth.getUser();

  if (userError || !user) {
    return json(
      { error: userError?.message ?? "Unauthorized" },
      { status: 401 },
    );
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const query = adminClient
    .from("runs")
    .select(
      "id, started_at, ended_at, duration, distance, created_at, user_id, point, avg_pace, calories, area, path_geom, loop_geom",
      { count: "exact" },
    )
    .eq("user_id", user.id)
    .order("started_at", { ascending: false })
    .range(offset, offset + limit - 1);

  const { data, error, count } = await query;

  if (error) {
    return json(
      {
        error: "Failed to fetch run history",
        details: error.message,
      },
      { status: 500 },
    );
  }

  const items = (data ?? []) as RunHistoryItem[];
  const runIds = items.map((item) => item.id).filter((id) => Number.isFinite(id));

  let splitsByRunId = new Map<number, RunSplitItem[]>();
  if (runIds.length > 0) {
    const { data: splitData, error: splitError } = await adminClient
      .from("run_splits")
      .select(
        "run_id, split_index, distance_m, duration_s, avg_pace_s_per_km, avg_speed_mps, ascent_m, calories, path_geom",
      )
      .in("run_id", runIds)
      .order("run_id", { ascending: true })
      .order("split_index", { ascending: true });

    if (splitError) {
      return json(
        {
          error: "Failed to fetch run splits",
          details: splitError.message,
        },
        { status: 500 },
      );
    }

    const splits = (splitData ?? []) as RunSplitItem[];
    splitsByRunId = splits.reduce((acc, split) => {
      const list = acc.get(split.run_id) ?? [];
      list.push(split);
      acc.set(split.run_id, list);
      return acc;
    }, new Map<number, RunSplitItem[]>());
  }

  const itemsWithSplits = items.map((item) => ({
    ...item,
    splits: splitsByRunId.get(item.id) ?? [],
  }));

  return json({
    items: itemsWithSplits,
    paging: {
      limit,
      offset,
      count: itemsWithSplits.length,
      total: count ?? itemsWithSplits.length,
      has_more: count != null ? offset + itemsWithSplits.length < count : itemsWithSplits.length === limit,
    },
  });
});
