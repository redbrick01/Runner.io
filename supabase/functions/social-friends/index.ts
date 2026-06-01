import { createClient } from "npm:@supabase/supabase-js@2.26.0";
import {
  aggregateHistoryScores,
  buildRejectedReopenPatch,
  getRangeBounds,
  isUniqueViolation,
  nextDateKey,
  parseAnchorDate,
  parseRangeType,
} from "./helpers.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

type JsonRecord = Record<string, unknown>;

type ProfileRow = {
  user_id: string;
  nick_name: string | null;
  color_hex: string | null;
  friend_code?: string | null;
};

type FriendshipRow = {
  id: string;
  requester_id: string;
  addressee_id: string;
  status: "pending" | "accepted" | "rejected";
  created_at: string;
  responded_at: string | null;
};

type FriendProfile = {
  user_id: string;
  nick_name: string | null;
  color_hex: string | null;
  friend_code?: string;
};

function json(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
      ...(init.headers ?? {}),
    },
  });
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function normalizeFriendCode(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const code = value.trim().toUpperCase();
  if (!/^[A-Z0-9]{8}$/.test(code)) return null;
  return code;
}

function startOfDayKst(dateKey: string) {
  return `${dateKey}T00:00:00+09:00`;
}

function profileFromRow(
  row: ProfileRow,
  includeFriendCode = false,
): FriendProfile {
  const profile: FriendProfile = {
    user_id: row.user_id,
    nick_name: row.nick_name,
    color_hex: row.color_hex,
  };
  if (includeFriendCode && row.friend_code) {
    profile.friend_code = row.friend_code;
  }
  return profile;
}

function profileMapFromRows(rows: ProfileRow[]): Map<string, ProfileRow> {
  const map = new Map<string, ProfileRow>();
  for (const row of rows) {
    map.set(row.user_id, row);
  }
  return map;
}

async function requireAuthenticatedUser(req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice("Bearer ".length).trim()
    : "";
  if (!token || token === SUPABASE_ANON_KEY) {
    return { error: "Missing access token", status: 401 };
  }

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    return {
      error: "Missing required Supabase environment variables",
      status: 500,
    };
  }

  const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await authClient.auth.getUser(token);
  if (error || !data.user) {
    return { error: "Invalid access token", status: 401 };
  }

  return { userId: data.user.id };
}

function adminClient() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function getAcceptedFriendIds(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<{ friendIds: string[] } | { response: Response }> {
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

  const friendIds = ((data ?? []) as Array<{
    requester_id: string;
    addressee_id: string;
  }>).map((row) =>
    row.requester_id === userId ? row.addressee_id : row.requester_id
  );
  return { friendIds: [...new Set(friendIds)] };
}

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    if (req.method !== "GET" && req.method !== "POST") {
      return json({ error: "Method not allowed" }, { status: 405 });
    }

    const auth = await requireAuthenticatedUser(req);
    if ("error" in auth) {
      return json({ error: auth.error }, { status: auth.status });
    }

    const supabase = adminClient();
    if (!supabase) {
      return json(
        { error: "Missing required Supabase environment variables" },
        { status: 500 },
      );
    }

    const userId = auth.userId;

    if (req.method === "GET") {
      const url = new URL(req.url);
      const mode = (url.searchParams.get("mode") ?? "me").toLowerCase();

      if (mode === "me") {
        const { data, error } = await supabase
          .from("profiles")
          .select("friend_code")
          .eq("user_id", userId)
          .maybeSingle();

        if (error) {
          return json(
            { error: "Failed to fetch friend code", details: error.message },
            { status: 500 },
          );
        }
        if (!data?.friend_code) {
          return json({ error: "Friend code not found" }, { status: 404 });
        }

        return json({ friend_code: data.friend_code });
      }

      if (mode === "lookup") {
        const friendCode = normalizeFriendCode(
          url.searchParams.get("friend_code"),
        );
        if (!friendCode) {
          return json({ error: "Invalid friend code" }, { status: 400 });
        }

        const { data, error } = await supabase
          .from("profiles")
          .select("user_id,nick_name,color_hex,friend_code")
          .eq("friend_code", friendCode)
          .maybeSingle();

        if (error) {
          return json(
            { error: "Failed to look up friend code", details: error.message },
            { status: 500 },
          );
        }
        if (!data || data.user_id === userId) {
          return json({ error: "Friend code not found" }, { status: 404 });
        }

        return json({ profile: profileFromRow(data as ProfileRow, true) });
      }

      if (mode === "requests") {
        const { data, error } = await supabase
          .from("friendships")
          .select("id,requester_id,addressee_id,status,created_at,responded_at")
          .eq("addressee_id", userId)
          .eq("status", "pending")
          .order("created_at", { ascending: false });

        if (error) {
          return json(
            {
              error: "Failed to fetch friend requests",
              details: error.message,
            },
            { status: 500 },
          );
        }

        const rows = (data ?? []) as FriendshipRow[];
        const requesterIds = [...new Set(rows.map((row) => row.requester_id))];
        const { data: profiles, error: profileError } = requesterIds.length > 0
          ? await supabase
            .from("profiles")
            .select("user_id,nick_name,color_hex")
            .in("user_id", requesterIds)
          : { data: [], error: null };

        if (profileError) {
          return json(
            {
              error: "Failed to fetch requester profiles",
              details: profileError.message,
            },
            { status: 500 },
          );
        }

        const profilesById = profileMapFromRows(
          (profiles ?? []) as ProfileRow[],
        );
        return json({
          requests: rows.map((row) => ({
            friendship_id: row.id,
            created_at: row.created_at,
            requester: profileFromRow(
              profilesById.get(row.requester_id) ?? {
                user_id: row.requester_id,
                nick_name: null,
                color_hex: null,
              },
            ),
          })),
        });
      }

      if (mode === "list") {
        const friendResult = await getAcceptedFriendIds(supabase, userId);
        if ("response" in friendResult) return friendResult.response;

        const { friendIds } = friendResult;
        const { data: profiles, error } = friendIds.length > 0
          ? await supabase
            .from("profiles")
            .select("user_id,nick_name,color_hex,friend_code")
            .in("user_id", friendIds)
          : { data: [], error: null };

        if (error) {
          return json(
            { error: "Failed to fetch friends", details: error.message },
            { status: 500 },
          );
        }

        const order = new Map(friendIds.map((id, index) => [id, index]));
        const friends = ((profiles ?? []) as ProfileRow[])
          .map((row) => profileFromRow(row, true))
          .sort((a, b) =>
            (order.get(a.user_id) ?? 0) - (order.get(b.user_id) ?? 0)
          );
        return json({ friends });
      }

      if (mode === "ranking") {
        const rangeType = parseRangeType(url.searchParams.get("range_type"));
        if (rangeType === "invalid") {
          return json({ error: "range_type must be week or month" }, {
            status: 400,
          });
        }

        const anchor = parseAnchorDate(url.searchParams.get("anchor_date"));
        if (!anchor.ok) {
          return json({ error: "anchor_date must be YYYY-MM-DD" }, {
            status: 400,
          });
        }

        const bounds = getRangeBounds(rangeType, anchor.date);
        const friendResult = await getAcceptedFriendIds(supabase, userId);
        if ("response" in friendResult) return friendResult.response;

        const participantIds = [
          ...new Set([userId, ...friendResult.friendIds]),
        ];

        const { data: profiles, error: profileError } = await supabase
          .from("profiles")
          .select("user_id,nick_name,color_hex")
          .in("user_id", participantIds);

        if (profileError) {
          return json(
            {
              error: "Failed to fetch ranking profiles",
              details: profileError.message,
            },
            { status: 500 },
          );
        }

        const profilesById = profileMapFromRows(
          (profiles ?? []) as ProfileRow[],
        );

        const { data: historyRows, error: historyError } = await supabase
          .from("point_history")
          .select("user_id,points_delta")
          .in("user_id", participantIds)
          .gte("created_at", startOfDayKst(bounds.from))
          .lt("created_at", startOfDayKst(nextDateKey(bounds.to)));

        if (historyError) {
          return json(
            {
              error: "Failed to fetch point history",
              details: historyError.message,
            },
            { status: 500 },
          );
        }
        const scoreMap = aggregateHistoryScores(
          (historyRows ?? []) as Array<
            { user_id: string; points_delta: number | null }
          >,
        );

        const ranked = participantIds
          .map((id) => {
            const profile = profilesById.get(id) ?? {
              user_id: id,
              nick_name: null,
              color_hex: null,
            };
            return {
              ...profileFromRow(profile),
              total_points: Number((scoreMap.get(id) ?? 0).toFixed(2)),
              display_rank: 1,
              is_self: id === userId,
            };
          })
          .sort((a, b) => {
            if (b.total_points !== a.total_points) {
              return b.total_points - a.total_points;
            }
            if (a.is_self !== b.is_self) return a.is_self ? -1 : 1;
            return a.user_id.localeCompare(b.user_id);
          });

        for (const row of ranked) {
          row.display_rank = 1 +
            ranked.filter((other) => other.total_points > row.total_points)
              .length;
        }

        return json({
          range: {
            range_type: rangeType,
            anchor_date: anchor.submitted,
            from: bounds.from,
            to: bounds.to,
          },
          results: ranked,
        });
      }

      return json({ error: "Invalid mode" }, { status: 400 });
    }

    const payload = await req.json().catch(() => null);
    if (!isRecord(payload)) {
      return json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const action = typeof payload.action === "string"
      ? payload.action.toLowerCase()
      : "";

    if (action === "request") {
      const friendCode = normalizeFriendCode(payload.friend_code);
      if (!friendCode) {
        return json({ error: "Invalid friend code" }, { status: 400 });
      }

      const { data: target, error: targetError } = await supabase
        .from("profiles")
        .select("user_id,nick_name,color_hex,friend_code")
        .eq("friend_code", friendCode)
        .maybeSingle();

      if (targetError) {
        return json(
          {
            error: "Failed to look up friend code",
            details: targetError.message,
          },
          { status: 500 },
        );
      }
      if (!target) {
        return json({ error: "Friend code not found" }, { status: 404 });
      }
      if (target.user_id === userId) {
        return json({ error: "Cannot request yourself" }, { status: 400 });
      }

      const targetId = target.user_id as string;
      const { data: existing, error: existingError } = await supabase
        .from("friendships")
        .select("id,requester_id,addressee_id,status,created_at,responded_at")
        .in("requester_id", [userId, targetId])
        .in("addressee_id", [userId, targetId])
        .maybeSingle();

      if (existingError) {
        return json(
          {
            error: "Failed to check friendship",
            details: existingError.message,
          },
          { status: 500 },
        );
      }

      const existingRow = existing as FriendshipRow | null;
      if (
        existingRow?.status === "pending" || existingRow?.status === "accepted"
      ) {
        return json(
          {
            error: `Friendship already ${existingRow.status}`,
            friendship_id: existingRow.id,
            status: existingRow.status,
          },
          { status: 409 },
        );
      }

      if (existingRow?.status === "rejected") {
        const { data: reopened, error: reopenError } = await supabase
          .from("friendships")
          .update(buildRejectedReopenPatch(userId, targetId))
          .eq("id", existingRow.id)
          .eq("status", "rejected")
          .select("id,status,created_at")
          .maybeSingle();

        if (reopenError) {
          return json(
            {
              error: "Failed to create friend request",
              details: reopenError.message,
            },
            { status: 500 },
          );
        }
        if (!reopened) {
          return json(
            {
              error: "Friendship changed while creating request",
              friendship_id: existingRow.id,
            },
            { status: 409 },
          );
        }

        return json({
          friendship_id: reopened.id,
          status: reopened.status,
          addressee: profileFromRow(target as ProfileRow, true),
        }, { status: 201 });
      }

      const { data: inserted, error: insertError } = await supabase
        .from("friendships")
        .insert({
          requester_id: userId,
          addressee_id: targetId,
          status: "pending",
        })
        .select("id,status,created_at")
        .single();

      if (insertError) {
        if (isUniqueViolation(insertError)) {
          return json(
            { error: "Friendship already exists" },
            { status: 409 },
          );
        }

        return json(
          {
            error: "Failed to create friend request",
            details: insertError.message,
          },
          { status: 500 },
        );
      }

      return json({
        friendship_id: inserted.id,
        status: inserted.status,
        addressee: profileFromRow(target as ProfileRow, true),
      }, { status: 201 });
    }

    if (action === "respond") {
      const friendshipId = typeof payload.friendship_id === "string"
        ? payload.friendship_id.trim()
        : "";
      const status = typeof payload.status === "string"
        ? payload.status.toLowerCase()
        : "";

      if (
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
          .test(friendshipId)
      ) {
        return json({ error: "Invalid friendship_id" }, { status: 400 });
      }
      if (status !== "accepted" && status !== "rejected") {
        return json({ error: "status must be accepted or rejected" }, {
          status: 400,
        });
      }

      const { data: friendship, error: friendshipError } = await supabase
        .from("friendships")
        .select("id,requester_id,addressee_id,status,created_at,responded_at")
        .eq("id", friendshipId)
        .maybeSingle();

      if (friendshipError) {
        return json(
          {
            error: "Failed to fetch friendship",
            details: friendshipError.message,
          },
          { status: 500 },
        );
      }
      if (!friendship) {
        return json({ error: "Friend request not found" }, { status: 404 });
      }

      const row = friendship as FriendshipRow;
      if (row.addressee_id !== userId) {
        return json({ error: "Cannot respond to another user's request" }, {
          status: 403,
        });
      }
      if (row.status !== "pending") {
        return json(
          {
            error: `Friend request already ${row.status}`,
            friendship_id: row.id,
            status: row.status,
          },
          { status: 409 },
        );
      }

      const { data: updated, error: updateError } = await supabase
        .from("friendships")
        .update({
          status,
          responded_at: new Date().toISOString(),
        })
        .eq("id", row.id)
        .eq("addressee_id", userId)
        .eq("status", "pending")
        .select("id,status,responded_at")
        .maybeSingle();

      if (updateError) {
        return json(
          {
            error: "Failed to update friend request",
            details: updateError.message,
          },
          { status: 500 },
        );
      }
      if (!updated) {
        return json(
          {
            error: "Friend request is no longer pending",
            friendship_id: row.id,
          },
          { status: 409 },
        );
      }

      return json({
        friendship_id: updated.id,
        status: updated.status,
        responded_at: updated.responded_at,
      });
    }

    return json({ error: "Invalid action" }, { status: 400 });
  } catch (error) {
    console.error("social-friends error:", error);
    return json({ error: "Internal server error" }, { status: 500 });
  }
});
