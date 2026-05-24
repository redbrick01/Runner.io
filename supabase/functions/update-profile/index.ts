import { createClient } from "npm:@supabase/supabase-js@2.33.0";

const ALLOWED_ORIGINS = (Deno.env.get("APP_ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((origin) => origin.trim())
  .filter((origin) => origin.length > 0);

const CORS_BASE_HEADERS = {
  "Access-Control-Allow-Methods": "POST,OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, apikey, x-client-info",
  "Vary": "Origin",
  "Access-Control-Allow-Credentials": "true",
};

function resolveAllowedOrigin(req: Request): string | null {
  const origin = req.headers.get("origin");
  if (!origin) return null;
  return ALLOWED_ORIGINS.includes(origin) ? origin : "";
}

function withCors(req: Request, headers: HeadersInit = {}) {
  const allowedOrigin = resolveAllowedOrigin(req);
  return {
    ...CORS_BASE_HEADERS,
    ...(allowedOrigin ? { "Access-Control-Allow-Origin": allowedOrigin } : {}),
    ...headers,
  };
}

function json(req: Request, body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: withCors(req, {
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    }),
  });
}

type SupabaseClients = {
  supabase: ReturnType<typeof createClient>;
  adminClient: ReturnType<typeof createClient>;
};

let cachedClients: SupabaseClients | null = null;

function getSupabaseClients(): SupabaseClients | null {
  if (cachedClients) return cachedClients;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Missing required Supabase environment variables");
    return null;
  }

  cachedClients = {
    supabase: createClient(supabaseUrl, anonKey),
    adminClient: createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    }),
  };
  return cachedClients;
}

Deno.serve(async (req: Request) => {
  try {
    // Handle preflight
    if (req.method === "OPTIONS") {
      if (resolveAllowedOrigin(req) === "") {
        return new Response(null, { status: 403 });
      }
      return new Response(null, {
        status: 204,
        headers: withCors(req, { "Content-Length": "0" }),
      });
    }

    if (resolveAllowedOrigin(req) === "") {
      return json(req, { error: "Origin not allowed" }, { status: 403 });
    }

    // Enforce allowed methods
    if (req.method !== "POST") {
      return json(req, { error: "Method not allowed" }, { status: 405 });
    }

    // Parse JSON body
    const contentType = req.headers.get("content-type") ?? "";
    if (!contentType.includes("application/json")) {
      return json(req, { error: "Expected application/json" }, { status: 400 });
    }

    const clients = getSupabaseClients();
    if (!clients) {
      return json(
        req,
        { error: "Missing required Supabase environment variables" },
        { status: 500 },
      );
    }

    const body = await req.json();

    // AUTH: Extract Bearer token if present
    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.split(" ")[1]
      : null;

    if (!token) {
      return json(req, { error: "Missing access token" }, { status: 401 });
    }

    // Validate token / get user
    const { data: userData, error: userError } = await clients.supabase.auth
      .getUser(token);
    if (userError || !userData?.user) {
      return json(req, { error: "Invalid token" }, { status: 401 });
    }
    const user = userData.user;

    // Prepare responses container
    const result: Record<string, unknown> = {};

    // 1) Password change flow (if provided)
    if (typeof body.password === "string") {
      const newPassword: string = body.password;

      // Simple policy: 최소 길이 8자 (원하시면 더 강화할 수 있습니다)
      if (newPassword.length < 8) {
        return json(
          req,
          { error: "Password must be at least 8 characters long" },
          { status: 400 },
        );
      }

      // Password changes are performed server-side after the bearer token
      // identifies the user, so the client never receives service-role access.
      const { data: pwData, error: pwError } = await clients.adminClient.auth
        .admin
        .updateUserById(user.id, {
          password: newPassword,
        });

      if (pwError) {
        console.error("Password update error:", pwError);
        return json(
          req,
          {
            error: "Failed to update password",
            details: pwError.message || pwError,
          },
          { status: 500 },
        );
      }

      result.password_change = {
        success: true,
        updated_at: pwData?.user?.updated_at ?? null,
      };
      // 권장: 클라이언트에게 세션 갱신/재로그인 필요성을 알림
      result.password_note =
        "Password changed. Client should refresh session or ask user to re-login if necessary.";
    }

    // 2) Profile update flow (optional fields)
    const updates: Record<string, unknown> = {};
    if (typeof body.nick_name === "string") updates.nick_name = body.nick_name;
    if (typeof body.color_hex === "string") updates.color_hex = body.color_hex;
    if (body.height_cm !== undefined) {
      const heightCm = Number(body.height_cm);
      if (!Number.isFinite(heightCm) || heightCm <= 0 || heightCm >= 300) {
        return json(
          req,
          { error: "height_cm must be a number between 1 and 299" },
          { status: 400 },
        );
      }
      updates.height_cm = heightCm;
    }
    if (body.weight_kg !== undefined) {
      const weightKg = Number(body.weight_kg);
      if (!Number.isFinite(weightKg) || weightKg <= 0 || weightKg >= 500) {
        return json(
          req,
          { error: "weight_kg must be a number between 1 and 499" },
          { status: 400 },
        );
      }
      updates.weight_kg = weightKg;
    }
    // 필요하면 여기에 더 많은 필드/유효성 검사 추가

    if (Object.keys(updates).length > 0) {
      const { data: updated, error: updateError } = await clients.adminClient
        .from("profiles")
        .update(updates)
        // 컬럼명이 user_id가 아니라면 변경 필요 (예: id)
        .eq("user_id", user.id)
        .select()
        .single();

      if (updateError) {
        console.error("DB update error:", updateError);
        return json(
          req,
          { error: "Failed to update profile" },
          { status: 500 },
        );
      }
      result.profile = updated;
    }

    if (Object.keys(result).length === 0) {
      return json(req, { error: "No valid fields to update" }, { status: 400 });
    }

    return json(req, { result }, { status: 200 });
  } catch (err) {
    console.error("Function error:", err);
    return json(req, { error: "Internal server error" }, { status: 500 });
  }
});
