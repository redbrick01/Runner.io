import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

console.log('user-info function booting')

Deno.serve(async (req: Request) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: req.headers.get('Authorization') ?? '',
        },
      },
    })

    // 로그인 사용자 확인
    const { data: userData, error: userError } = await supabase.auth.getUser()

    if (userError || !userData?.user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    const user_id = userData.user.id

    // RPC 호출
    const { data, error } = await supabase.rpc('get_user_info', {
      p_user_id: user_id,
    })

    if (error) {
      throw error
    }

    const row = data?.[0]

    const result = row
      ? {
          rank: row.rank,
          area: row.area,
          profile: {
            id: row.id,
            nick_name: row.nick_name,
            total_points: row.total_points,
            color_hex: row.color_hex,
            created_at: row.created_at,
            user_id: row.user_id,
          },
        }
      : null

    return new Response(
      JSON.stringify({ data: result }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  } catch (err: any) {
    console.error('user-info error:', err)

    return new Response(
      JSON.stringify({ error: err.message ?? 'Internal Server Error' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})