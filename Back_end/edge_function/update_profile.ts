import { createClient } from "npm:@supabase/supabase-js@2.33.0";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*", // 개발용: 프로덕션에서는 특정 origin만 허용하세요
  "Access-Control-Allow-Methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey, x-client-info",
  "Access-Control-Allow-Credentials": "true",
};

function withCors(headers: HeadersInit = {}) {
  return {
    ...CORS_HEADERS,
    ...headers,
  };
}

Deno.serve(async (req: Request) => {
    
  try {
    const url = new URL(req.url);

    // Handle preflight
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: withCors({ "Content-Length": "0" }),
      });
    }

    // Enforce allowed methods
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: withCors({ "Content-Type": "application/json" }),
      });
    }

    // Parse JSON body
    const contentType = req.headers.get("content-type") ?? "";
    if (!contentType.includes("application/json")) {
      return new Response(JSON.stringify({ error: "Expected application/json" }), {
        status: 400,
        headers: withCors({ "Content-Type": "application/json" }),
      });
    }

    const body = await req.json();

    // AUTH: Extract Bearer token if present
    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.split(" ")[1] : null;

    if (!token) {
      return new Response(JSON.stringify({ error: "Missing access token" }), {
        status: 401,
        headers: withCors({ "Content-Type": "application/json" }),
      });
    }

    // Validate token / get user
    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    if (userError || !userData?.user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: withCors({ "Content-Type": "application/json" }),
      });
    }
    const user = userData.user;

    // Prepare responses container
    const result: Record<string, unknown> = {};

    // 1) Password change flow (if provided)
    if (typeof body.password === "string") {
      const newPassword: string = body.password;

      // Simple policy: 최소 길이 8자 (원하시면 더 강화할 수 있습니다)
      if (newPassword.length < 8) {
        return new Response(
          JSON.stringify({ error: "Password must be at least 8 characters long" }),
          { status: 400, headers: withCors({ "Content-Type": "application/json" }) }
        );
      }

      // Attempt to update user's password using their token
      const { data: pwData, error: pwError } = await supabase.auth.updateUser(token, {
        password: newPassword,
      } as any);
      // Note: supabase-js v2 updateUser signature might accept options differently;
      // using updateUser with token context via client may vary. If this call errors,
      // consider using admin endpoint on server with service_role key (security implications).

      if (pwError) {
        console.error("Password update error:", pwError);
        return new Response(
          JSON.stringify({ error: "Failed to update password", details: pwError.message || pwError }),
          { status: 500, headers: withCors({ "Content-Type": "application/json" }) }
        );
      }

      result.password_change = { success: true, updated_at: pwData?.data?.updated_at ?? null };
      // 권장: 클라이언트에게 세션 갱신/재로그인 필요성을 알림
      result.password_note = "Password changed. Client should refresh session or ask user to re-login if necessary.";
    }

    // 2) Profile update flow (optional fields)
    const updates: Record<string, unknown> = {};
    if (typeof body.nick_name === "string") updates.nick_name = body.nick_name;
    if (typeof body.color_hex === "string") updates.color_hex = body.color_hex;
    // 필요하면 여기에 더 많은 필드/유효성 검사 추가

    if (Object.keys(updates).length > 0) {
      const { data: updated, error: updateError } = await supabase
        .from("profiles")
        .update(updates)
        // 컬럼명이 user_id가 아니라면 변경 필요 (예: id)
        .eq("user_id", user.id)
        .select()
        .single();

      if (updateError) {
        console.error("DB update error:", updateError);
        return new Response(JSON.stringify({ error: "Failed to update profile" }), {
          status: 500,
          headers: withCors({ "Content-Type": "application/json" }),
        });
      }
      result.profile = updated;
    }

    if (Object.keys(result).length === 0) {
      return new Response(JSON.stringify({ error: "No valid fields to update" }), {
        status: 400,
        headers: withCors({ "Content-Type": "application/json" }),
      });
    }

    return new Response(JSON.stringify({ result }), {
      status: 200,
      headers: withCors({ "Content-Type": "application/json" }),
    });
  } catch (err) {
    console.error("Function error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: withCors({ "Content-Type": "application/json" }),
    });
  }
});