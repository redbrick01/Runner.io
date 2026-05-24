import { serve } from "https://deno.land/std@0.201.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2.26.0";

console.info("create-run function starting");

type JsonRecord = Record<string, unknown>;

type RunInsertRow = {
  started_at: unknown;
  ended_at: unknown;
  duration: unknown;
  distance: unknown;
  point: unknown;
  path_geom: unknown;
  avg_pace: unknown;
  calories: number | null;
  user_id: string;
};

type SplitInsertRow = {
  run_id: unknown;
  split_index: number;
  distance_m: number;
  duration_s: number;
  avg_pace_s_per_km: number | null;
  avg_speed_mps: number | null;
  ascent_m: number;
  calories: number | null;
  path_geom: string | null;
};

function toFiniteNumber(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "string" && value.trim() === "") return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return parsed;
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validateFiniteNumber(
  value: unknown,
  fieldName: string,
  min: number,
  max: number,
): { value: number } | { error: string } {
  const parsed = toFiniteNumber(value);
  if (parsed === null || parsed < min || parsed > max) {
    return {
      error: `${fieldName} must be a number between ${min} and ${max}`,
    };
  }
  return { value: parsed };
}

function validatePathGeom(
  value: unknown,
): { value: string } | { error: string } {
  if (typeof value !== "string") {
    return { error: "path_geom must be a WKT LineString or MultiLineString" };
  }

  const normalized = value.trim().toUpperCase();
  const isSupportedType = normalized.startsWith("LINESTRING") ||
    normalized.startsWith("MULTILINESTRING");
  const containsCoordinates = normalized.includes("(") &&
    normalized.includes(")");
  if (!isSupportedType || !containsCoordinates || value.length > 200000) {
    return {
      error: "path_geom must be a valid WKT LineString or MultiLineString",
    };
  }

  return { value };
}

function json(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

let cachedSupabase: ReturnType<typeof createClient> | null = null;

function getSupabaseClient(): ReturnType<typeof createClient> | null {
  if (cachedSupabase) return cachedSupabase;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return null;
  }

  cachedSupabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  return cachedSupabase;
}

function estimateMetFromSpeed(avgSpeedKmH: number): number {
  if (avgSpeedKmH < 6.5) return 6.0;
  if (avgSpeedKmH < 8.0) return 8.3;
  if (avgSpeedKmH < 9.7) return 9.8;
  if (avgSpeedKmH < 11.3) return 11.0;
  if (avgSpeedKmH < 12.9) return 11.8;
  return 12.8;
}

function estimateCalories(
  distanceMeters: number,
  durationSeconds: number,
  weightKg: number,
): number | null {
  if (distanceMeters <= 0 || durationSeconds <= 0 || weightKg <= 0) {
    return null;
  }
  const distanceKm = distanceMeters / 1000;
  const durationHours = durationSeconds / 3600;
  if (durationHours <= 0) return null;
  const avgSpeedKmH = distanceKm / durationHours;
  const met = estimateMetFromSpeed(avgSpeedKmH);
  const calories = met * weightKg * durationHours;
  if (!Number.isFinite(calories) || calories < 0) return null;
  return Number(calories.toFixed(1));
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, { status: 405 });
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      return json(
        { error: "Missing required Supabase environment variables" },
        { status: 500 },
      );
    }

    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) {
      return json({ error: "Missing authorization token" }, { status: 401 });
    }

    // Verify token and get user
    const { data: userData, error: userError } = await supabase.auth.getUser(
      token,
    );
    if (userError || !userData?.user) {
      return json({ error: "Invalid token" }, { status: 401 });
    }
    const uid = userData.user.id;

    const payload = await req.json().catch(() => null);
    if (!isRecord(payload)) {
      return json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const required = [
      "started_at",
      "ended_at",
      "duration",
      "distance",
      "point",
      "path_geom",
      "avg_pace",
    ];
    for (const f of required) {
      if (payload[f] === undefined || payload[f] === null) {
        return json({ error: `Missing field ${f}` }, { status: 400 });
      }
    }

    const distanceValue = toFiniteNumber(payload.distance);
    const durationValue = toFiniteNumber(payload.duration);
    const distanceValidation = validateFiniteNumber(
      payload.distance,
      "distance",
      1,
      200000,
    );
    if ("error" in distanceValidation) {
      return json({ error: distanceValidation.error }, { status: 400 });
    }

    const durationValidation = validateFiniteNumber(
      payload.duration,
      "duration",
      1,
      86400,
    );
    if ("error" in durationValidation) {
      return json({ error: durationValidation.error }, { status: 400 });
    }

    const pointValidation = validateFiniteNumber(
      payload.point,
      "point",
      0,
      100000,
    );
    if ("error" in pointValidation) {
      return json({ error: pointValidation.error }, { status: 400 });
    }

    const pathGeomValidation = validatePathGeom(payload.path_geom);
    if ("error" in pathGeomValidation) {
      return json({ error: pathGeomValidation.error }, { status: 400 });
    }

    let caloriesValue = toFiniteNumber(payload.calories);

    // Fallback: 클라이언트가 calories를 보내지 않았거나 비정상 값이면 서버에서 보정 계산
    if (
      caloriesValue === null && distanceValue !== null && durationValue !== null
    ) {
      const { data: profileData, error: profileError } = await supabase
        .from("profiles")
        .select("weight_kg")
        .eq("user_id", uid)
        .maybeSingle();
      if (profileError) {
        console.error(
          "Profile lookup error for calorie fallback",
          profileError,
        );
      } else {
        const weightKg = toFiniteNumber(profileData?.weight_kg);
        if (weightKg !== null) {
          caloriesValue = estimateCalories(
            distanceValue,
            durationValue,
            weightKg,
          );
        }
      }
    }

    const insertRow: RunInsertRow = {
      started_at: payload.started_at,
      ended_at: payload.ended_at,
      duration: durationValidation.value,
      distance: distanceValidation.value,
      point: pointValidation.value,
      path_geom: pathGeomValidation.value,
      avg_pace: payload.avg_pace,
      calories: caloriesValue,
      user_id: uid,
    };

    const { data, error } = await supabase.from("runs").insert([insertRow])
      .select().single();
    if (error) {
      console.error("Insert error", error);
      return json({ error: error.message }, { status: 500 });
    }

    const runId = data?.id;
    const splits = Array.isArray(payload.splits) ? payload.splits : [];
    if (runId && splits.length > 0) {
      const splitRows: SplitInsertRow[] = splits
        .map((split: unknown, index: number): SplitInsertRow | null => {
          if (!isRecord(split)) return null;
          const distanceM = Number(split?.distance_m);
          const durationS = Number(split?.duration_s);
          if (!Number.isFinite(distanceM) || distanceM <= 0) return null;
          if (!Number.isFinite(durationS) || durationS <= 0) return null;

          const splitIndexRaw = Number(split?.split_index);
          const splitIndex = Number.isFinite(splitIndexRaw) && splitIndexRaw > 0
            ? Math.floor(splitIndexRaw)
            : index + 1;

          const ascentM = toFiniteNumber(split?.ascent_m);
          const avgPace = toFiniteNumber(split?.avg_pace_s_per_km);
          const avgSpeed = toFiniteNumber(split?.avg_speed_mps);
          const calories = toFiniteNumber(split?.calories);

          return {
            run_id: runId,
            split_index: splitIndex,
            distance_m: distanceM,
            duration_s: durationS,
            avg_pace_s_per_km: avgPace,
            avg_speed_mps: avgSpeed,
            ascent_m: ascentM ?? 0,
            calories: calories,
            path_geom: typeof split?.path_geom === "string"
              ? split.path_geom
              : null,
          };
        })
        .filter((row): row is SplitInsertRow => row !== null);

      if (splitRows.length > 0) {
        const { error: splitError } = await supabase
          .from("run_splits")
          .insert(splitRows);

        if (splitError) {
          console.error("Split insert error", splitError);
          await supabase
            .from("runs")
            .delete()
            .eq("id", runId);
          return json(
            {
              error: `Failed to save run splits: ${splitError.message}`,
            },
            { status: 500 },
          );
        }
      }
    }

    //성공
    return json(data, { status: 201 });
  } catch (err) {
    console.error(err);
    return json({ error: "Internal error" }, { status: 500 });
  }
});
