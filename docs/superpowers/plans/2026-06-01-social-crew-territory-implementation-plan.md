# Social Crew Territory Implementation Plan

Date: 2026-06-01
Spec: `docs/superpowers/specs/2026-06-01-social-crew-territory-design.md`

## Overview

Build the social MVP in small vertical slices:

1. Database schema and server-side rules.
2. Friend APIs.
3. Crew APIs and season scoring.
4. Crew contribution support in run saving.
5. Scoped territory GeoJSON for personal, friends, and crew layers.
6. Flutter service models.
7. Social tab UI.
8. Map layer switcher.
9. Run save crew contribution selector.
10. Verification and documentation.

Keep the implementation aligned with the existing app pattern: Flutter pages call focused service classes, services call Supabase Edge Functions through `SupabaseApi`, and backend functions return normalized JSON.

## Task 1: Social Database Foundation

**Files:**
- Create: `supabase/migrations/20260601090000_add_social_crew_territory.sql`
- Test manually with Supabase SQL editor or local Supabase migration flow if available.

- [ ] **Step 1: Add migration with social tables**

Create the migration with these concepts:

```sql
alter table public.profiles
  add column if not exists friend_code text;

create unique index if not exists profiles_friend_code_key
  on public.profiles (friend_code)
  where friend_code is not null;

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint friendships_no_self check (requester_id <> addressee_id)
);

create unique index if not exists friendships_pair_unique
  on public.friendships (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  );

create table if not exists public.crews (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  region text,
  color_hex text,
  is_public boolean not null default true,
  creator_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists crews_public_search_idx
  on public.crews (is_public, deleted_at, region, created_at desc);

create table if not exists public.crew_members (
  id uuid primary key default gen_random_uuid(),
  crew_id uuid not null references public.crews(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  is_default_contribution boolean not null default false,
  last_contributed_at timestamptz,
  left_at timestamptz,
  unique (crew_id, user_id)
);

create index if not exists crew_members_user_active_idx
  on public.crew_members (user_id, left_at, is_default_contribution desc);

create table if not exists public.crew_seasons (
  id uuid primary key default gen_random_uuid(),
  season_type text not null check (season_type in ('week', 'month')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'active' check (status in ('active', 'closed')),
  unique (season_type, starts_at, ends_at)
);

create table if not exists public.run_crew_contributions (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.runs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  crew_id uuid not null references public.crews(id) on delete cascade,
  contribution_area_m2 double precision not null default 0,
  contribution_score double precision not null default 0,
  created_at timestamptz not null default now(),
  unique (run_id)
);

create index if not exists run_crew_contributions_crew_created_idx
  on public.run_crew_contributions (crew_id, created_at desc);
```

- [ ] **Step 2: Add helper functions for friend code backfill**

Add a SQL helper that creates readable unique friend codes for profiles without one. Use uppercase base derived from random UUID data. Keep it deterministic enough for migration safety but unique enough for normal use.

```sql
create or replace function public.generate_friend_code()
returns text
language plpgsql
as $$
declare
  candidate text;
begin
  loop
    candidate := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (
      select 1 from public.profiles where friend_code = candidate
    );
  end loop;
  return candidate;
end;
$$;

update public.profiles
set friend_code = public.generate_friend_code()
where friend_code is null;

alter table public.profiles
  alter column friend_code set not null;
```

- [ ] **Step 3: Add RLS policies or document Edge Function-only writes**

If existing tables use RLS, add RLS policies for authenticated reads/writes. If the app relies on service-role Edge Functions for mutations, enable read policies only where direct client reads are needed and keep all writes inside Edge Functions. The plan should prefer Edge Function-only writes because existing services call Edge Functions.

- [ ] **Step 4: Verify migration**

Run:

```bash
supabase db lint
```

Expected: no SQL errors. If local Supabase CLI is unavailable, apply the migration in the project’s Supabase workflow and record the result in the final implementation notes.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260601090000_add_social_crew_territory.sql
git commit -m "feat: add social crew schema"
```

## Task 2: Friend Edge Function

**Files:**
- Create: `supabase/functions/social-friends/index.ts`
- Test: `supabase/functions/social-friends/index.test.ts` if the repo has Deno test setup; otherwise test through function calls.
- Modify: `supabase/functions/README.md`

- [ ] **Step 1: Define API modes**

Implement one Edge Function named `social-friends` with:

- `GET ?mode=me`: returns current user's `friend_code`.
- `GET ?mode=lookup&friend_code=ABC12345`: returns compact profile if found and not self.
- `GET ?mode=requests`: returns incoming pending requests.
- `GET ?mode=list`: returns accepted friends.
- `GET ?mode=ranking&range_type=week|month&anchor_date=YYYY-MM-DD`: returns current user plus accepted friends ranked by points.
- `POST { "action": "request", "friend_code": "ABC12345" }`
- `POST { "action": "respond", "friendship_id": "...", "status": "accepted" | "rejected" }`

Response shapes:

```ts
type FriendProfile = {
  user_id: string;
  nick_name: string | null;
  color_hex: string | null;
  friend_code?: string;
};

type FriendRankingItem = FriendProfile & {
  total_points: number;
  display_rank: number;
  is_self: boolean;
};
```

- [ ] **Step 2: Implement auth and validation**

Use the same auth pattern as `profile-leaderboard` and `territory-geojson`: read bearer token, verify user, and use service-role client for controlled queries. Block:

- Missing token.
- Invalid friend code.
- Self request.
- Duplicate pending or accepted relationship.
- Responding to someone else's request.

- [ ] **Step 3: Implement ranking**

For `mode=ranking`, reuse the date-bound logic from `profile-leaderboard`. Query only the current user and accepted friends. Return normalized rank rows sorted by score descending.

- [ ] **Step 4: Verify**

Run targeted function checks against a seeded database:

```bash
supabase functions serve social-friends
```

Expected:

- Lookup unknown code returns 404.
- Request self returns 400.
- Duplicate request returns 409.
- Accepted friends appear in `mode=list`.
- Ranking excludes non-friends.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/social-friends supabase/functions/README.md
git commit -m "feat: add friend social function"
```

## Task 3: Crew Edge Function And Season Scoring

**Files:**
- Create: `supabase/functions/social-crews/index.ts`
- Modify: `supabase/functions/README.md`

- [ ] **Step 1: Define API modes**

Implement one Edge Function named `social-crews` with:

- `GET ?mode=search&q=&region=&sort=score|members|activity|new&limit=20`
- `GET ?mode=my`: joined active crews, default/recent first.
- `GET ?mode=detail&crew_id=...`: crew profile, season score, member contribution ranking.
- `GET ?mode=ranking&season_type=week|month&anchor_date=YYYY-MM-DD`: crew season ranking.
- `POST { "action": "join", "crew_id": "..." }`
- `POST { "action": "leave", "crew_id": "..." }`
- `POST { "action": "set_default", "crew_id": "..." }`

The MVP must keep crews freely joinable: a public, non-deleted crew can be joined immediately without owner approval, operator approval, or a join request queue.

Response shapes:

```ts
type CrewSummary = {
  id: string;
  name: string;
  description: string | null;
  region: string | null;
  color_hex: string | null;
  member_count: number;
  season_score: number;
  cumulative_area_m2: number;
  is_joined: boolean;
  is_default_contribution: boolean;
};

type CrewMemberContribution = {
  user_id: string;
  nick_name: string | null;
  color_hex: string | null;
  contribution_score: number;
  contribution_area_m2: number;
  display_rank: number;
};
```

- [ ] **Step 2: Implement season bounds**

Use KST-aligned week and month bounds to match existing ranking behavior. Week starts Monday. Month starts on day 1. This task implements weekly and monthly season score windows; all-time cumulative area is only a secondary display metric.

- [ ] **Step 3: Implement season score**

Calculate score from `run_crew_contributions` created inside the selected season. Use:

```ts
final_score = raw_contribution_score - maintenance_penalty
```

For MVP, set `maintenance_penalty` to `0` unless the implementation has a reliable inactivity date per crew. If adding the penalty now, only reduce score; never alter territory geometry.

- [ ] **Step 4: Implement search**

Search public, non-deleted crews by name and region. Sort by selected sort mode. Do not implement pace or goal filtering.

- [ ] **Step 5: Verify**

Check:

- Public crews appear in search.
- Joining twice returns an already-joined response instead of duplicating membership.
- Leaving marks `left_at`.
- Default crew is unique per user.
- Ranking uses season score, not all-time area.

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/social-crews supabase/functions/README.md
git commit -m "feat: add crew social function"
```

## Task 4: Run Save Crew Contribution

**Files:**
- Modify: `supabase/functions/create-run/index.ts`
- Modify: `lib/services/run_save_payload.dart`
- Modify: `lib/services/run_service.dart` only if a typed wrapper helps.
- Test: `test/run_save_payload_test.dart`

- [ ] **Step 1: Write failing Dart payload tests**

Add tests that verify optional crew contribution serialization:

```dart
test('includes selected crew contribution id when provided', () {
  final payload = RunSavePayload(
    startedAt: DateTime.utc(2026, 6, 1),
    endedAt: DateTime.utc(2026, 6, 1, 0, 30),
    durationSeconds: 1800,
    distanceMeters: 5000,
    point: 50,
    avgPaceSecondsPerKm: 360,
    pathGeom: 'LINESTRING(127.0 37.0,127.1 37.1)',
    crewContributionId: 'crew-1',
  );

  expect(payload.toCreateRunBody()['crew_id'], 'crew-1');
});

test('omits crew id when contribution is disabled', () {
  final body = minimalRunSavePayload(crewContributionId: null).toCreateRunBody();
  expect(body.containsKey('crew_id'), isFalse);
});
```

If constructor names differ, adapt to the current `RunSavePayload` fields.

- [ ] **Step 2: Extend payload model**

Add `String? crewContributionId` to `RunSavePayload`, copy helpers if present, and emit `crew_id` only when non-empty.

- [ ] **Step 3: Extend `create-run`**

After inserting the run and calculating run area/points, if `payload.crew_id` exists:

1. Verify current user is an active member of the crew.
2. Verify membership `joined_at <= run.started_at`.
3. Insert `run_crew_contributions`.
4. Update `crew_members.last_contributed_at`.
5. Make the selected crew the user's default/recent contribution crew.

If crew contribution insert fails after the run is saved, return a successful run response with a warning field:

```json
{
  "run": { "...": "..." },
  "crew_contribution": { "applied": false, "error": "..." }
}
```

- [ ] **Step 4: Verify**

Run:

```bash
flutter test test/run_save_payload_test.dart
```

Expected: payload tests pass.

Then validate function behavior with seeded membership:

- Joined before run: contribution inserted.
- Joined after run start: contribution rejected but run preserved.
- No `crew_id`: existing create-run behavior unchanged.

- [ ] **Step 5: Commit**

```bash
git add lib/services/run_save_payload.dart lib/services/run_service.dart supabase/functions/create-run/index.ts test/run_save_payload_test.dart
git commit -m "feat: add crew contribution to run save"
```

## Task 5: Scoped Territory GeoJSON

**Files:**
- Modify: `supabase/functions/territory-geojson/index.ts`
- Modify: `lib/services/territory_service.dart`
- Modify: `lib/services/running_map_service.dart`
- Test: `test/territory_service_test.dart`

- [ ] **Step 1: Choose extension over new function**

Extend `territory-geojson` with `scope=personal|friends|crew` because the existing function already handles auth, bbox parsing, GeoJSON filtering, and map response shape. This is lower risk than duplicating geometry code.

- [ ] **Step 2: Add Dart service tests**

Add tests for query parameter construction:

```dart
test('fetchTerritories sends scope and crew id', () async {
  final result = TerritoryQuery(
    bbox: '126.9,37.4,127.1,37.6',
    limit: 100,
    scope: TerritoryScope.crew,
    crewId: 'crew-1',
  ).toQueryParameters();

  expect(result['scope'], 'crew');
  expect(result['crew_id'], 'crew-1');
});
```

Use a small query object if direct service testing is hard because `SupabaseApi` is static.

- [ ] **Step 3: Extend backend scope handling**

Add:

- `personal`: current behavior or current user's territory depending on existing default.
- `friends`: only accepted friend user IDs.
- `crew`: crew territory for a selected joined crew or default crew.

Return the same FeatureCollection shape as today, with properties that Flutter can already parse:

```json
{
  "type": "Feature",
  "properties": {
    "owner_type": "crew",
    "owner_id": "...",
    "nick_name": "Crew Name",
    "color_hex": "#2F80ED",
    "area": 12345.6
  },
  "geometry": {}
}
```

- [ ] **Step 4: Extend Flutter service signature**

Add:

```dart
enum TerritoryScope { personal, friends, crew }
```

and extend `TerritoryService.fetchTerritories` with optional `scope` and `crewId`.

- [ ] **Step 5: Verify**

Run:

```bash
flutter test test/territory_service_test.dart
flutter analyze lib/services/territory_service.dart lib/services/running_map_service.dart
```

Expected: tests pass and analyzer has no new issues.

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/territory-geojson/index.ts lib/services/territory_service.dart lib/services/running_map_service.dart test/territory_service_test.dart
git commit -m "feat: add scoped territory geojson"
```

## Task 6: Flutter Social And Crew Services

**Files:**
- Create: `lib/services/social_service.dart`
- Create: `lib/services/crew_service.dart`
- Modify: `lib/services/README.md`
- Test: `test/social_service_model_test.dart`
- Test: `test/crew_service_model_test.dart`

- [ ] **Step 1: Write model parsing tests**

Cover:

- Friend code response.
- Friend lookup result.
- Incoming request row.
- Friend ranking item.
- Crew summary.
- Crew detail member contribution.

Example:

```dart
test('parses crew summary from json', () {
  final crew = CrewSummary.fromJson({
    'id': 'crew-1',
    'name': 'Gangnam Runners',
    'description': 'Territory crew',
    'region': 'Gangnam',
    'color_hex': '#2364AA',
    'member_count': 12,
    'season_score': 123.5,
    'cumulative_area_m2': 4567.0,
    'is_joined': true,
    'is_default_contribution': false,
  });

  expect(crew.name, 'Gangnam Runners');
  expect(crew.memberCount, 12);
});
```

- [ ] **Step 2: Implement service models and methods**

`SocialService` should expose:

- `fetchMyFriendCode()`
- `lookupFriendCode(String code)`
- `sendFriendRequest(String code)`
- `fetchIncomingRequests()`
- `respondToFriendRequest(String friendshipId, FriendResponse response)`
- `fetchFriends()`
- `fetchFriendRanking({required String rangeType, DateTime? anchorDate})`

`CrewService` should expose:

- `searchCrews({String? query, String? region, CrewSort sort, int limit})`
- `fetchMyCrews()`
- `fetchCrewDetail(String crewId)`
- `fetchCrewRanking({required String seasonType, DateTime? anchorDate})`
- `joinCrew(String crewId)`
- `leaveCrew(String crewId)`
- `setDefaultCrew(String crewId)`

- [ ] **Step 3: Update services README**

Document the new service responsibilities in `lib/services/README.md`.

- [ ] **Step 4: Verify**

Run:

```bash
flutter test test/social_service_model_test.dart test/crew_service_model_test.dart
flutter analyze lib/services/social_service.dart lib/services/crew_service.dart
```

Expected: tests pass and analyzer has no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/services/social_service.dart lib/services/crew_service.dart lib/services/README.md test/social_service_model_test.dart test/crew_service_model_test.dart
git commit -m "feat: add social service layer"
```

## Task 7: Social Tab UI

**Files:**
- Create: `lib/main/social_page.dart`
- Modify: `lib/main.dart`
- Modify: `lib/main/README.md`
- Test: `test/social_page_test.dart`

- [ ] **Step 1: Write widget tests**

Test these states with fake service adapters or injectable callbacks:

- Shows friend code area.
- Shows friend code search input.
- Shows empty friend list.
- Shows incoming request actions.
- Shows crew search entry.
- Shows crew ranking empty state.

- [ ] **Step 2: Build `SocialPage`**

Use existing design tokens from `app_colors.dart` and `design/app_design.dart`. The page should have segmented sections:

- Friends.
- Crews.
- Ranking.

Keep UI dense and operational. Do not add marketing text or feed-like content.

- [ ] **Step 3: Connect bottom Social item**

In `lib/main.dart` or the current bottom navigation owner, connect the existing Social tab/icon to `SocialPage`.

If the Social item is built inside `RunningMapPage`, move only the minimum navigation wiring needed. Avoid broad navigation refactors.

- [ ] **Step 4: Verify**

Run:

```bash
flutter test test/social_page_test.dart
flutter analyze lib/main/social_page.dart lib/main.dart
```

Expected: tests pass and analyzer has no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/main/social_page.dart lib/main.dart lib/main/README.md test/social_page_test.dart
git commit -m "feat: add social tab"
```

## Task 8: Map Territory Layer Switcher

**Files:**
- Modify: `lib/main/running_map_page.dart`
- Test: `test/territory_layer_state_test.dart`

- [ ] **Step 1: Extract layer state where possible**

Add a small enum and helper outside the large widget internals:

```dart
enum TerritoryLayer { personal, friends, crew }

extension TerritoryLayerQuery on TerritoryLayer {
  TerritoryScope get scope {
    switch (this) {
      case TerritoryLayer.personal:
        return TerritoryScope.personal;
      case TerritoryLayer.friends:
        return TerritoryScope.friends;
      case TerritoryLayer.crew:
        return TerritoryScope.crew;
    }
  }
}
```

- [ ] **Step 2: Write state tests**

Test that selected layer maps to the right service scope and that crew layer carries the selected/default crew ID when present.

- [ ] **Step 3: Add UI control**

Add a segmented control or compact chip row over the map with:

- 개인
- 친구
- 크루

Changing the layer should clear current territory overlays, fetch scoped GeoJSON, and keep the map camera unchanged.

- [ ] **Step 4: Handle errors**

On layer fetch failure, leave the map visible, clear only territory overlays for the failed layer, and show a small retry action.

- [ ] **Step 5: Verify**

Run:

```bash
flutter test test/territory_layer_state_test.dart
flutter analyze lib/main/running_map_page.dart
```

Expected: tests pass and analyzer has no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/main/running_map_page.dart test/territory_layer_state_test.dart
git commit -m "feat: add territory layer switcher"
```

## Task 9: Run Save Crew Selector UI

**Files:**
- Modify: `lib/main/run_result_page.dart`
- Modify: `lib/services/run_save_payload.dart`
- Test: `test/run_result_crew_selector_test.dart`

- [ ] **Step 1: Write widget tests**

Test:

- No joined crews: selector shows contribution disabled state.
- Joined crews: default/recent crew selected.
- User can select no contribution.
- User can switch to another joined crew.
- Saved payload contains selected crew ID only when contribution is enabled.

- [ ] **Step 2: Load joined crews**

Use `CrewService.fetchMyCrews()` in the run result/save page. Keep failure non-blocking: if crews fail to load, allow the run to save without crew contribution.

- [ ] **Step 3: Add selector UI**

Add a compact selector near the save action:

- Label: `크루 기여`
- Selected crew name or `기여 안 함`
- Bottom sheet or dialog for choosing among joined crews.

- [ ] **Step 4: Persist default/recent crew**

After a successful save with a crew contribution, rely on backend to mark the crew as default/recent. Refresh local crew list on next page load.

- [ ] **Step 5: Verify**

Run:

```bash
flutter test test/run_result_crew_selector_test.dart test/run_save_payload_test.dart
flutter analyze lib/main/run_result_page.dart lib/services/run_save_payload.dart
```

Expected: tests pass and analyzer has no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/main/run_result_page.dart lib/services/run_save_payload.dart test/run_result_crew_selector_test.dart
git commit -m "feat: select crew contribution when saving runs"
```

## Task 10: End-To-End Verification And Docs

**Files:**
- Modify: `lib/README.md`
- Modify: `lib/main/README.md`
- Modify: `lib/services/README.md`
- Modify: `supabase/functions/README.md`
- Create: `docs/new_features/social_crew_territory_mvp.md`

- [ ] **Step 1: Run full Flutter checks**

Run:

```bash
flutter test
flutter analyze
```

Expected: all tests pass and analyzer has no new issues.

- [ ] **Step 2: Run targeted backend checks**

Run function-level checks available in the repo. If no automated Deno tests exist, manually verify these endpoints against a seeded project:

- `social-friends` lookup/request/respond/list/ranking.
- `social-crews` search/join/my/detail/ranking.
- `create-run` with and without `crew_id`.
- `territory-geojson` with `scope=personal`, `scope=friends`, and `scope=crew`.

- [ ] **Step 3: Update docs**

Document:

- Social tab responsibilities.
- Friend code flow.
- Crew search/join flow.
- Crew contribution rule.
- Territory layer scopes.
- Out-of-scope items that remain intentionally absent.

- [ ] **Step 4: Manual device checks**

On a device or simulator with map support:

- Open the Social tab.
- Add a friend by code.
- Join a public crew.
- Switch map layers between personal, friends, and crew.
- Save a run with crew contribution.
- Confirm the crew ranking changes after backend refresh.

- [ ] **Step 5: Commit**

```bash
git add lib/README.md lib/main/README.md lib/services/README.md supabase/functions/README.md docs/new_features/social_crew_territory_mvp.md
git commit -m "docs: document social crew territory mvp"
```

## Execution Notes

- Do not implement feed, comments, likes, chat, crew notices, crew approval, pace matching, private map sharing, or strong territory decay.
- Keep backend ranking calculations server-side.
- Keep Flutter pages free of raw HTTP logic.
- Prefer adding small model/helper classes over expanding already-large page methods.
- Treat `RunningMapPage` edits carefully because it is already large and map behavior is hard to widget-test completely.
- Because the current worktree has unrelated local changes, each execution task must stage only the files listed in that task.
