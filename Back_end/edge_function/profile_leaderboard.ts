import { createClient } from "npm:@supabase/supabase-js@2.26.0";

console.info('profile-leaderboard starting');

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON = Deno.env.get('SUPABASE_ANON_KEY')!;
if (!SUPABASE_URL || !SUPABASE_ANON) console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY');

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON, { auth: { persistSession: false } });

Deno.serve(async (req: Request) => {
  try {
    const url = new URL(req.url);
    const params = url.searchParams;
    const mode = (params.get('mode') || 'top').toLowerCase();

    if (mode === 'top') {
      // top 10 by total_points desc
      const { data, error } = await supabase
        .from('profiles')
        .select('user_id, nick_name, total_points')
        .order('total_points', { ascending: false })
        .limit(10);

      if (error) {
        console.error('Query error', error);
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'Content-Type': 'application/json' } });
      }

      return new Response(JSON.stringify({ mode: 'top', results: data }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }

    if (mode === 'context') {
      const user_id = params.get('user_id');
      if (!user_id) {
        return new Response(JSON.stringify({ error: 'Missing user_id parameter' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
      }

      // Get the rank of the user
      // Using window function in RPC via SQL is not available via supabase-js select; use from('profiles').select with count? We'll run a raw SQL via supabase.rpc is not suited. Instead, fetch user's total_points then query around that value with ordering and limit+offset.

      const { data: userRow, error: userErr } = await supabase
        .from('profiles')
        .select('user_id, nick_name, total_points')
        .eq('user_id', user_id)
        .maybeSingle();

      if (userErr) {
        console.error('User lookup error', userErr);
        return new Response(JSON.stringify({ error: userErr.message }), { status: 500, headers: { 'Content-Type': 'application/json' } });
      }
      if (!userRow) {
        return new Response(JSON.stringify({ error: 'User not found' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
      }

      const userPoints = userRow.total_points || 0;

      // Count how many have more points than the user to compute rank
      const { count: higherCount, error: cntErr } = await supabase
        .from('profiles')
        .select('user_id', { count: 'exact', head: true })
        .gt('total_points', userPoints);

      if (cntErr) {
        console.error('Count error', cntErr);
      }

      const rank = (higherCount || 0) + 1;

      // Fetch up to 50 above: those with total_points > userPoints ordered desc limit 50
      const { data: above, error: aboveErr } = await supabase
        .from('profiles')
        .select('user_id, nick_name, total_points')
        .gt('total_points', userPoints)
        .order('total_points', { ascending: false })
        .limit(50);

      if (aboveErr) console.error('Above query error', aboveErr);

      // Fetch up to 50 below: total_points < userPoints ordered desc (so closer ones first)
      const { data: below, error: belowErr } = await supabase
        .from('profiles')
        .select('user_id, nick_name, total_points')
        .lt('total_points', userPoints)
        .order('total_points', { ascending: false })
        .limit(50);

      if (belowErr) console.error('Below query error', belowErr);

      return new Response(JSON.stringify({ mode: 'context', user: { ...userRow, rank }, above: above || [], self: userRow, below: below || [] }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }

    return new Response(JSON.stringify({ error: 'Invalid mode' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: 'Internal error' }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});