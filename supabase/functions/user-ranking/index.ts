import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
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

  const authHeader = req.headers.get("Authorization");
  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: authHeader ? { headers: { Authorization: authHeader } } : undefined,
  });

  const {
    data: { user },
    error: userError,
  } = await authClient.auth.getUser();

  if (userError || !user) {
    return json({ error: "Unauthorized" }, { status: 401 });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await adminClient.rpc("get_user_info", {
    p_user_id: user.id,
  });

  if (error) {
    return json(
      { error: "Failed to fetch user profile", details: error.message },
      { status: 500 },
    );
  }

  const profile = Array.isArray(data) ? data[0] ?? null : data;
  if (!profile) {
    return json({
      data: {
        rank: 0,
        area: 0,
        profile: {
          user_id: user.id,
          nick_name: user.email?.split("@")[0] ?? "나",
          total_points: 0,
          color_hex: "#448AFF",
        },
      },
    });
  }

  return json({
    data: {
      rank: profile.rank ?? 0,
      area: profile.area ?? 0,
      profile,
    },
  });
});
