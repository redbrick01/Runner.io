import { createClient } from "npm:@supabase/supabase-js@2.26.0";
console.info('territory-geojson starting');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON = Deno.env.get('SUPABASE_ANON_KEY')!;
if (!SUPABASE_URL || !SUPABASE_ANON) console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY');
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON, { auth: { persistSession: false } });

Deno.serve(async (req: Request) => {
  try {
    const url = new URL(req.url);
    const params = url.searchParams;
    const bbox = params.get('bbox'); // minX,minY,maxX,maxY
    const srid = parseInt(params.get('srid') || '4326');
    const limit = Math.min(parseInt(params.get('limit') || '1000'), 5000);

    let sql = `SELECT t.user_id, p.nick_name, p.color_hex, t.area, ST_AsGeoJSON(ST_Transform(t.geom, $1)) AS geom_json FROM public.territories t JOIN public.profiles p ON p.user_id = t.user_id`;
    const args: any[] = [srid];
    if (bbox) {
      const parts = bbox.split(',').map(s => parseFloat(s));
      if (parts.length !== 4 || parts.some(isNaN)) {
        return new Response(JSON.stringify({ error: 'Invalid bbox format. Use minX,minY,maxX,maxY' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
      }
      // ST_MakeEnvelope(minX, minY, maxX, maxY, srid) but need to transform bbox from srid to geometry original SRID (assume geom is 4326). We'll transform envelope to geom SRID 4326 if srid differs.
      // We'll accept bbox as the same SRID as requested output for simplicity and transform envelope to geom's SRID (assume 4326).
      sql += ` WHERE ST_Intersects(t.geom, ST_Transform(ST_MakeEnvelope($2,$3,$4,$5,$1), ST_SRID(t.geom)))`;
      args.push(parts[0], parts[1], parts[2], parts[3]);
    }
    sql += ` LIMIT ${limit}`;

    const { data, error } = await supabase.rpc('sql', { q: sql, params: args });
    // Note: supabase-js doesn't provide generic raw SQL via rpc('sql') by default. Instead use from().select with text? As a workaround, call REST SQL endpoint via supabase.postgrest.

    // Use postgrest to query via queryRaw
    const { data: rawData, error: rawErr } = await supabase.postgrest.rpc('sql', { q: sql, params: args });
    if (rawErr) {
      console.error('Raw SQL error', rawErr);
      // Fallback: try using from('territories').select with transform -- but ST_AsGeoJSON can't be used. Return error.
      return new Response(JSON.stringify({ error: 'Database query error' }), { status: 500, headers: { 'Content-Type': 'application/json' } });
    }

    // rawData expected as array of rows with geom_json
    const features = (rawData as any[]).map(r => ({
      type: 'Feature',
      properties: { user_id: r.user_id, nick_name: r.nick_name, color_hex: r.color_hex, area: r.area },
      geometry: JSON.parse(r.geom_json)
    }));

    const fc = { type: 'FeatureCollection', features };
    return new Response(JSON.stringify(fc), { status: 200, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: 'Internal error' }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});