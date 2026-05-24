import { createClient } from "npm:@supabase/supabase-js@2.26.0";
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

type TerritoryRow = {
  user_id: string;
  nick_name: string | null;
  color_hex: string | null;
  area: number | null;
  geom_json: string;
};

type Bbox = {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
};

type GeoJsonGeometry = {
  type: string;
  coordinates: unknown;
};

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
    const { data, error } = await supabase.rpc(
      "get_territories_geojson",
      rpcArgs,
    );
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
            nick_name: r.nick_name,
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
  } catch (err) {
    console.error("Internal error:", err);
    return json({ error: "Internal error" }, { status: 500 });
  }
});
