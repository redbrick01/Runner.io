import { createClient } from "npm:@supabase/supabase-js@2.26.0";
import { buildFriendScopeUserIds } from "./helpers.ts";
console.info("territory-geojson starting");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

type TerritoryRpcArgs = {
  in_srid: number;
  in_limit: number;
  in_minx: number | null;
  in_miny: number | null;
  in_maxx: number | null;
  in_maxy: number | null;
};

type UserTerritoryRpcArgs = TerritoryRpcArgs & {
  in_user_ids: string[];
};

type CrewTerritoryRpcArgs = TerritoryRpcArgs & {
  in_crew_id: string | null;
};

type TerritoryRow = {
  user_id: string;
  nick_name: string | null;
  color_hex: string | null;
  area: number | null;
  geom_json: string;
};

type CrewTerritoryRow = {
  crew_id: string;
  name: string;
  color_hex: string | null;
  area: number | null;
  geom_json: string;
};

type TerritoryScope = "personal" | "friends" | "crew";

type Bbox = {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
};

type CrewRow = {
  id: string;
  name: string;
  color_hex: string | null;
};

type CrewContext = {
  id: string;
  name: string;
  colorHex: string | null;
};

type GeoJsonGeometry = {
  type: string;
  coordinates: unknown;
};

type SupabaseClient = ReturnType<typeof createClient>;

function json(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

function parseBbox(value: string | null): Bbox | null | "invalid" {
  if (!value) return null;

  const parts = value.split(",").map((s) => parseFloat(s));
  if (parts.length !== 4 || parts.some(Number.isNaN)) {
    return "invalid";
  }

  const [minX, minY, maxX, maxY] = parts;
  if (
    minX > maxX || minY > maxY ||
    minX < -180 || maxX > 180 ||
    minY < -90 || maxY > 90
  ) {
    return "invalid";
  }

  return { minX, minY, maxX, maxY };
}

function parseBoundedInt(
  value: string | null,
  fallback: number,
  min: number,
  max: number,
): number | "invalid" {
  const parsed = parseInt(value ?? `${fallback}`, 10);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    return "invalid";
  }
  return parsed;
}

function parseScope(value: string | null): TerritoryScope | null | "invalid" {
  if (value === null || value.trim() === "") return null;

  const normalized = value.trim().toLowerCase();
  if (
    normalized === "personal" || normalized === "friends" ||
    normalized === "crew"
  ) {
    return normalized;
  }
  return "invalid";
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{12}$/i
    .test(value);
}

async function requireAuthenticatedUser(req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice("Bearer ".length).trim()
    : "";
  if (!token || token === SUPABASE_ANON) {
    return { error: "Missing access token", status: 401 };
  }

  if (!SUPABASE_URL || !SUPABASE_ANON) {
    return {
      error: "Missing required Supabase environment variables",
      status: 500,
    };
  }

  const authClient = createClient(SUPABASE_URL, SUPABASE_ANON, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
  const { data, error } = await authClient.auth.getUser(token);
  if (error || !data.user) {
    return { error: "Invalid access token", status: 401 };
  }

  return { userId: data.user.id };
}

async function fetchAcceptedFriendIds(
  supabase: SupabaseClient,
  userId: string,
): Promise<{ userIds: string[] } | { response: Response }> {
  const { data, error } = await supabase
    .from("friendships")
    .select("requester_id,addressee_id")
    .eq("status", "accepted")
    .or(`requester_id.eq.${userId},addressee_id.eq.${userId}`);

  if (error) {
    return {
      response: json(
        { error: "Failed to fetch friendships", details: error.message },
        { status: 500 },
      ),
    };
  }

  const userIds = ((data ?? []) as Array<{
    requester_id: string;
    addressee_id: string;
  }>).map((row) =>
    row.requester_id === userId ? row.addressee_id : row.requester_id
  );

  return { userIds: [...new Set(userIds)] };
}

async function fetchCrewById(
  supabase: SupabaseClient,
  crewId: string,
): Promise<{ crew: CrewRow | null } | { response: Response }> {
  const { data, error } = await supabase
    .from("crews")
    .select("id,name,color_hex")
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

async function resolveCrewContext(
  supabase: SupabaseClient,
  userId: string,
  crewId: string,
): Promise<{ crew: CrewContext | null } | { response: Response }> {
  if (!isUuid(crewId)) {
    return {
      response: json({ error: "crew_id must be a valid UUID" }, {
        status: 400,
      }),
    };
  }

  const crewResult = await fetchCrewById(supabase, crewId);
  if ("response" in crewResult) return crewResult;
  if (!crewResult.crew) {
    return { response: json({ error: "Crew not found" }, { status: 404 }) };
  }

  const { data, error } = await supabase
    .from("crew_members")
    .select("crew_id")
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
  if (!data) {
    return {
      response: json({ error: "Active crew membership required" }, {
        status: 403,
      }),
    };
  }

  return {
    crew: {
      id: crewResult.crew.id,
      name: crewResult.crew.name,
      colorHex: crewResult.crew.color_hex,
    },
  };
}

function ringBounds(ring: unknown): Bbox | null {
  if (!Array.isArray(ring)) return null;

  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  let hasPoint = false;

  for (const point of ring) {
    if (!Array.isArray(point) || point.length < 2) continue;
    const x = Number(point[0]);
    const y = Number(point[1]);
    if (!Number.isFinite(x) || !Number.isFinite(y)) continue;

    minX = Math.min(minX, x);
    minY = Math.min(minY, y);
    maxX = Math.max(maxX, x);
    maxY = Math.max(maxY, y);
    hasPoint = true;
  }

  return hasPoint ? { minX, minY, maxX, maxY } : null;
}

function intersects(a: Bbox, b: Bbox): boolean {
  return a.minX <= b.maxX && a.maxX >= b.minX &&
    a.minY <= b.maxY && a.maxY >= b.minY;
}

function filterGeometryByBbox(
  geometry: GeoJsonGeometry,
  bbox: Bbox | null,
): GeoJsonGeometry | null {
  if (!bbox) return geometry;

  if (geometry.type === "Polygon" && Array.isArray(geometry.coordinates)) {
    const bounds = ringBounds(geometry.coordinates[0]);
    return bounds && intersects(bounds, bbox) ? geometry : null;
  }

  if (geometry.type === "MultiPolygon" && Array.isArray(geometry.coordinates)) {
    const filtered = geometry.coordinates.filter((polygon) => {
      if (!Array.isArray(polygon)) return false;
      const bounds = ringBounds(polygon[0]);
      return bounds !== null && intersects(bounds, bbox);
    });

    if (filtered.length === 0) return null;
    return {
      ...geometry,
      coordinates: filtered,
    };
  }

  return geometry;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "GET") {
      return json({ error: "Method not allowed" }, { status: 405 });
    }

    if (!SUPABASE_URL || !SUPABASE_ANON || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(
        { error: "Missing required Supabase environment variables" },
        { status: 500 },
      );
    }

    const auth = await requireAuthenticatedUser(req);
    if ("error" in auth) {
      return json({ error: auth.error }, { status: auth.status });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const url = new URL(req.url);
    const params = url.searchParams;
    const bbox = parseBbox(params.get("bbox"));
    if (bbox === "invalid") {
      return json(
        { error: "Invalid bbox format. Use minX,minY,maxX,maxY" },
        { status: 400 },
      );
    }

    const srid = parseBoundedInt(params.get("srid"), 4326, 4326, 4326);
    if (srid === "invalid") {
      return json({ error: "srid must be 4326" }, { status: 400 });
    }

    const limit = parseBoundedInt(params.get("limit"), 1000, 1, 1000);
    if (limit === "invalid") {
      return json(
        { error: "limit must be an integer between 1 and 1000" },
        { status: 400 },
      );
    }
    const scope = parseScope(params.get("scope"));
    if (scope === "invalid") {
      return json(
        { error: "scope must be personal, friends, or crew" },
        { status: 400 },
      );
    }

    const crewId = params.get("crew_id")?.trim() || null;
    let scopedUserIds: string[] | null = null;
    let crewContext: CrewContext | null = null;
    if (scope === "personal") {
      scopedUserIds = [auth.userId];
    } else if (scope === "friends") {
      const friendsResult = await fetchAcceptedFriendIds(supabase, auth.userId);
      if ("response" in friendsResult) return friendsResult.response;
      scopedUserIds = buildFriendScopeUserIds(
        auth.userId,
        friendsResult.userIds,
      );
    } else if (scope === "crew") {
      if (crewId) {
        const crewResult = await resolveCrewContext(
          supabase,
          auth.userId,
          crewId,
        );
        if ("response" in crewResult) return crewResult.response;
        crewContext = crewResult.crew;
      }
    } else if (crewId) {
      return json(
        { error: "crew_id can only be used with scope=crew" },
        { status: 400 },
      );
    }

    let rpcArgs: TerritoryRpcArgs = {
      in_srid: srid,
      in_limit: limit,
      in_minx: null,
      in_miny: null,
      in_maxx: null,
      in_maxy: null,
    };
    if (bbox) {
      rpcArgs = {
        ...rpcArgs,
        in_minx: bbox.minX,
        in_miny: bbox.minY,
        in_maxx: bbox.maxX,
        in_maxy: bbox.maxY,
      };
    }

    if (scope === "crew") {
      const crewRpcArgs: CrewTerritoryRpcArgs = {
        ...rpcArgs,
        in_crew_id: crewContext?.id ?? null,
      };
      const { data, error } = await supabase.rpc(
        "get_crew_territories_geojson",
        crewRpcArgs,
      );
      if (error) {
        console.error("Crew territory RPC error:", error);
        return json({ error: error.message }, { status: 500 });
      }

      const features = ((data ?? []) as CrewTerritoryRow[])
        .map((r) => {
          const geometry = filterGeometryByBbox(
            JSON.parse(r.geom_json) as GeoJsonGeometry,
            bbox,
          );
          if (!geometry) return null;

          return {
            type: "Feature",
            properties: {
              user_id: null,
              owner_type: "crew",
              owner_id: r.crew_id,
              nick_name: r.name,
              color_hex: r.color_hex,
              area: r.area,
            },
            geometry,
          };
        })
        .filter((feature) => feature !== null);

      return json({
        type: "FeatureCollection",
        features,
      });
    }

    const rpcName = scopedUserIds === null
      ? "get_territories_geojson"
      : "get_territories_geojson_for_users";
    const scopedRpcArgs: TerritoryRpcArgs | UserTerritoryRpcArgs =
      scopedUserIds === null
        ? rpcArgs
        : { ...rpcArgs, in_user_ids: scopedUserIds };
    const { data, error } = await supabase.rpc(rpcName, scopedRpcArgs);
    if (error) {
      console.error("RPC error:", error);
      return json({ error: error.message }, { status: 500 });
    }

    const features = ((data ?? []) as TerritoryRow[])
      .map((r) => {
        const geometry = filterGeometryByBbox(
          JSON.parse(r.geom_json) as GeoJsonGeometry,
          bbox,
        );
        if (!geometry) return null;

        return {
          type: "Feature",
          properties: {
            user_id: r.user_id,
            ...(scope
              ? {
                owner_type: "user",
                owner_id: r.user_id,
              }
              : {}),
            nick_name: r.nick_name,
            color_hex: r.color_hex,
            area: r.area,
          },
          geometry,
        };
      })
      .filter((feature) => feature !== null)
      .slice(0, limit);

    return json({
      type: "FeatureCollection",
      features,
    });
  } catch (err) {
    console.error("Internal error:", err);
    return json({ error: "Internal error" }, { status: 500 });
  }
});
