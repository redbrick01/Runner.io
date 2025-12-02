import { createClient } from "npm:@supabase/supabase-js@2.26.0";

console.info("create-run function starting");

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) {
      return new Response(JSON.stringify({ error: "Missing authorization token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 토큰 검증 및 사용자 정보 조회
    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    if (userError || !userData?.user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
    const uid = userData.user.id;

    const payload = await req.json().catch(() => null);
    if (!payload) {
      return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const required = ["started_at", "ended_at", "duration", "distance", "point", "path_geom"];
    for (const f of required) {
      if (payload[f] === undefined || payload[f] === null) {
        return new Response(JSON.stringify({ error: `Missing field ${f}` }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }
    }

    // runs 삽입
    const insertRow: any = {
      started_at: payload.started_at,
      ended_at: payload.ended_at,
      duration: payload.duration,
      distance: payload.distance,
      point: payload.point,
      path_geom: payload.path_geom,
      user_id: uid,
    };

    const { data: runData, error: runError } = await supabase
      .from("runs")
      .insert([insertRow])
      .select()
      .single();

    if (runError) {
      console.error("Insert run error", runError);
      return new Response(JSON.stringify({ error: runError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    // profiles에서 현재 total_points 조회
    const { data: profileData, error: profileError } = await supabase
      .from("profiles")
      .select("total_points")
      .eq("user_id", uid)
      .single();

    const currentTotal = !profileError && profileData ? (profileData.total_points || 0) : 0;
    const newTotal = currentTotal + insertRow.point;

    // profiles.total_points 업데이트 (없으면 upsert)
    const { data: updatedProfile, error: updateError } = await supabase
      .from("profiles")
      .update({ total_points: newTotal })
      .eq("user_id", uid)
      .select()
      .single();

    if (updateError) {
      const { data: upsertProfile, error: upsertError } = await supabase
        .from("profiles")
        .upsert({ user_id: uid, total_points: newTotal }, { onConflict: "user_id" })
        .select()
        .single();

      if (upsertError) {
        console.warn("Failed to update or upsert profile total_points", upsertError);
      } else {
        console.log("Upserted profile total points:", upsertProfile?.total_points);
      }
    } else {
      console.log("Updated total points:", updatedProfile?.total_points);
    }

    // point_history 스키마에 맞춰 삽입: (event_type, points_delta, created_at, user_id)
    const phRow: any = {
      event_type: payload.reason || "run_completed",
      points_delta: insertRow.point,
      created_at: new Date().toISOString(),
      user_id: uid,
    };

    const { data: phData, error: phError } = await supabase
      .from("point_history")
      .insert([phRow])
      .select()
      .single();

    if (phError) {
      console.error("Insert point_history error", phError);
      return new Response(
        JSON.stringify({
          run: runData,
          warning: "Run created but failed to insert point_history",
          point_history_error: phError.message,
        }),
        { status: 201, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ run: runData, point_history: phData }), {
      status: 201,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: "Internal error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});