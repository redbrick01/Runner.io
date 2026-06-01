CREATE OR REPLACE FUNCTION public.get_territories_geojson_for_users(
  in_user_ids uuid[],
  in_srid integer DEFAULT 4326,
  in_minx double precision DEFAULT NULL::double precision,
  in_miny double precision DEFAULT NULL::double precision,
  in_maxx double precision DEFAULT NULL::double precision,
  in_maxy double precision DEFAULT NULL::double precision,
  in_limit integer DEFAULT 1000
)
RETURNS TABLE(
  user_id uuid,
  nick_name text,
  color_hex text,
  area double precision,
  geom_json text
)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT
    t.user_id,
    p.nick_name,
    p.color_hex,
    t.area,
    ST_AsGeoJSON(ST_Transform(t.geom, in_srid)) AS geom_json
  FROM public.territories t
  JOIN public.profiles p ON p.user_id = t.user_id
  WHERE
    t.user_id = ANY(COALESCE(in_user_ids, ARRAY[]::uuid[]))
    AND (
      in_minx IS NULL OR in_miny IS NULL OR in_maxx IS NULL OR in_maxy IS NULL
      OR ST_Intersects(
        t.geom,
        ST_Transform(
          ST_MakeEnvelope(in_minx, in_miny, in_maxx, in_maxy, in_srid),
          ST_SRID(t.geom)
        )
      )
    )
  LIMIT LEAST(GREATEST(in_limit, 1), 5000);
$$;

CREATE OR REPLACE FUNCTION public.get_crew_territories_geojson(
  in_crew_id uuid,
  in_srid integer DEFAULT 4326,
  in_minx double precision DEFAULT NULL::double precision,
  in_miny double precision DEFAULT NULL::double precision,
  in_maxx double precision DEFAULT NULL::double precision,
  in_maxy double precision DEFAULT NULL::double precision,
  in_limit integer DEFAULT 1000
)
RETURNS TABLE(
  crew_id uuid,
  name text,
  color_hex text,
  area double precision,
  geom_json text
)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH contribution_geoms AS (
    SELECT
      rcc.crew_id,
      c.name,
      c.color_hex,
      rcc.contribution_area_m2,
      ST_SetSRID(ST_Force2D(r.loop_geom), COALESCE(NULLIF(ST_SRID(r.loop_geom), 0), 4326)) AS geom
    FROM public.run_crew_contributions rcc
    JOIN public.runs r ON r.id = rcc.run_id
    JOIN public.crews c ON c.id = rcc.crew_id
    WHERE rcc.crew_id = in_crew_id
      AND r.loop_geom IS NOT NULL
      AND (
        in_minx IS NULL OR in_miny IS NULL OR in_maxx IS NULL OR in_maxy IS NULL
        OR ST_Intersects(
          ST_SetSRID(ST_Force2D(r.loop_geom), COALESCE(NULLIF(ST_SRID(r.loop_geom), 0), 4326)),
          ST_Transform(
            ST_MakeEnvelope(in_minx, in_miny, in_maxx, in_maxy, in_srid),
            COALESCE(NULLIF(ST_SRID(r.loop_geom), 0), 4326)
          )
        )
      )
  ),
  aggregated AS (
    SELECT
      crew_id,
      name,
      color_hex,
      COALESCE(SUM(contribution_area_m2), 0)::double precision AS area,
      ST_UnaryUnion(ST_Collect(geom)) AS geom
    FROM contribution_geoms
    GROUP BY crew_id, name, color_hex
  )
  SELECT
    a.crew_id,
    a.name,
    a.color_hex,
    a.area,
    ST_AsGeoJSON(ST_Transform(a.geom, in_srid)) AS geom_json
  FROM aggregated a
  WHERE a.geom IS NOT NULL
    AND NOT ST_IsEmpty(a.geom)
  LIMIT LEAST(GREATEST(in_limit, 1), 5000);
$$;

GRANT ALL ON FUNCTION public.get_territories_geojson_for_users(
  uuid[], integer, double precision, double precision, double precision, double precision, integer
) TO anon, authenticated, service_role;

GRANT ALL ON FUNCTION public.get_crew_territories_geojson(
  uuid, integer, double precision, double precision, double precision, double precision, integer
) TO anon, authenticated, service_role;
