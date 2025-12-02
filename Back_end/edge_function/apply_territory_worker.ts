const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
}

Deno.serve(async (req) => {
  try {
    // Query expired territories first to avoid unnecessary function calls
    const res = await fetch(`${SUPABASE_URL}/rest/v1/territories?select=user_id&next_process_at=lte.now`, {
      method: 'GET',
      headers: {
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
      }
    })

    if (!res.ok) {
      const text = await res.text()
      return new Response(JSON.stringify({ error: 'failed to fetch territories', details: text }), { status: 500 })
    }

    const rows = await res.json()
    if (!Array.isArray(rows) || rows.length === 0) {
      return new Response(JSON.stringify({ processed: 0 }), { status: 200 })
    }

    // Call apply_territory_points once (function handles all territories)
    const rpcRes = await fetch(`${SUPABASE_URL}/rpc/apply_territory_points`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      }
    })

    if (!rpcRes.ok) {
      const text = await rpcRes.text()
      return new Response(JSON.stringify({ error: 'rpc_failed', details: text }), { status: 500 })
    }

    return new Response(JSON.stringify({ processed: rows.length }), { status: 200 })
  } catch (err) {
    console.error(err)
    return new Response(JSON.stringify({ error: 'unexpected_error', message: String(err) }), { status: 500 })
  }
})