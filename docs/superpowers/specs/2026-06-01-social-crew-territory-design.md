# Social Crew Territory Design

Date: 2026-06-01
Status: Draft approved for planning

## Goal

Add a social MVP that makes running more motivating through friends, public crews, map territory layers, and season-based crew territory competition.

The feature is not a general SNS. The first release excludes feeds, comments, reactions, chat, crew notices, approval workflows, and private map sharing settings. It focuses on relationship setup, territory visibility, and ranking competition.

## Product Shape

The MVP has three entry points.

1. Social tab: the relationship and competition hub.
2. Main map layer switcher: the visual territory battlefield.
3. Run save flow: the moment a run is assigned to a crew contribution.

The current bottom navigation already shows a Social item but does not have a connected social page. The MVP should connect that item to a real Social page.

The existing personal territory system remains the base. Crew territory extends it instead of introducing a separate territory rule system.

## Social Tab

The Social tab should provide:

- My friend code with copy action.
- Friend code search and friend request creation.
- Incoming friend requests with accept and reject actions.
- Friend list.
- Friend weekly and monthly ranking.
- Crew search.
- My crews.
- Crew season ranking.

The page can use internal tabs or segmented controls for Friends, Crews, and Ranking. The first screen should be useful without requiring a deep navigation path.

## Friend Model

Each user gets a unique friend code. Users cannot search all users by nickname for the MVP. They search by exact friend code, see a compact profile result, then send a friend request.

Friendship states:

- `pending`: request sent and waiting for response.
- `accepted`: both users are friends.
- `rejected` or deletion support can exist server-side, but the MVP UI only needs accept/reject for incoming requests and a stable friend list.

Maps and territories are already public in the current product concept. Friendship does not unlock private data. It lets users filter public territory data to friends and compare with friends in weekly/monthly rankings.

## Crew Model

Crews are public and freely joinable for the MVP. There is no crew owner management, operator role, or join approval in the first release.

Crew search should support:

- Name.
- Representative region.
- Activity level.
- Member count.
- Current season territory score.

Crew search should not focus on running goal or pace. The product concept is territory conquest, not pace matching.

Crew details should be ranking-centered because the main map already covers the visual territory experience. A crew detail page should prioritize:

- Current season rank.
- Current season territory score.
- Member contribution ranking.
- Cumulative occupied area as a secondary metric.
- Recent contribution summary as supporting context.

## Territory Layers

The main running map should add a layer control with:

- Personal: existing personal territory behavior.
- Friends: territories from accepted friends.
- Crew: selected crew or my default/recent crew territory.

The map should continue using territory polygons and labels. The backend should return layer-specific GeoJSON so Flutter does not need to calculate territory ownership locally.

The existing `territory-geojson` Edge Function can be extended with a scope parameter, or a new `social-territory-geojson` function can be added. The implementation plan should choose the lower-risk option after inspecting the current Edge Function code.

## Crew Contribution Rules

Crew contribution combines two user choices:

1. Only runs after joining a crew can contribute to that crew.
2. At run save time, the user can choose which joined crew receives the contribution.

If the user has joined crews, the run save screen should default to the representative or most recently used crew. The user can change it to another joined crew or choose no crew contribution.

Past runs must not automatically affect crew scores after a user joins a crew.

## Season And Scoring

Crew territory is cumulative on the map, but rankings are season-based.

The MVP should support weekly and monthly seasons. The main ranking metric is season territory score.

Territory defense is intentionally light in the first release. If a crew leaves territory inactive for a period, the map territory stays visible, but season score can decrease through a maintenance penalty. No territory should disappear or become neutralized in the MVP.

The exact scoring formula can be simple in the first implementation, but it must preserve these principles:

- More joined-after, selected-crew territory contribution increases score.
- Maintenance activity can protect score.
- Inactivity can reduce season score.
- The penalty affects ranking score only, not the displayed cumulative territory geometry.

## Data Model

The backend should add or extend data around these concepts:

- User profile friend code.
- Friendships with requester, addressee, and status.
- Crews with name, description, representative region, public visibility, color, and creator metadata.
- Crew members with user, crew, joined date, and default/recent contribution marker.
- Run crew contributions with run, user, crew, contribution area, contribution score, and created time.
- Crew seasons with type, start time, end time, and status.
- Crew season scores with raw contribution, maintenance penalty, final score, and rank.

The exact SQL names can follow the existing Supabase naming conventions discovered during implementation. Row-level security and Edge Function checks must ensure users can only mutate their own friend requests, memberships, and run contribution choices.

## Backend API Shape

Flutter should keep following the current service-layer pattern and call Edge Functions through `SupabaseApi`.

Likely API groups:

- Friend code lookup.
- Friend request create/list/respond.
- Friend list and friend ranking.
- Crew search/list/join/leave.
- My crews and default contribution crew.
- Crew detail and crew rankings.
- Run save contribution support.
- Territory GeoJSON by scope.

Friend and crew ranking calculations should happen server-side. Flutter should receive normalized JSON that is easy to render and test.

## Flutter Structure

Add focused service classes instead of putting HTTP logic in pages:

- `SocialService` for friend code lookup, requests, friends, and friend rankings.
- `CrewService` for search, membership, crew details, and crew rankings.
- Extend `TerritoryService` for scoped territory GeoJSON.
- Extend run save payload/service to include optional crew contribution.

Add focused pages/widgets:

- `SocialPage`.
- Friend code/search/request widgets.
- Friend list and friend ranking widgets.
- Crew search/list/detail widgets.
- Crew contribution selector in the run result/save flow.
- Map layer segmented control in `RunningMapPage`.

`RunningMapPage` is already large, so implementation should keep new layer-state parsing and UI pieces small and extracted where practical.

## Error Handling

Errors should be recoverable and specific:

- Invalid friend code: tell the user to check the code.
- Duplicate friendship or pending request: show the current state.
- Self friend request: block with a clear message.
- Crew already joined: show joined state.
- Crew unavailable: show a short unavailable message.
- Map layer fetch failure: keep the map visible, clear only the failed layer, and offer retry.
- Run saved but crew contribution failed: preserve the run and explain that crew contribution did not apply.

## Privacy And Safety

The MVP follows the current product assumption that territory maps are public. Friend features filter and rank public data rather than unlocking private map data.

Friend code search limits user discovery compared with nickname search. Crew search is public by design. The data model should leave room for future crew approval, blocking, and report flows without building those flows now.

## Testing

Backend and service tests should cover:

- Unique friend code lookup.
- Duplicate request prevention.
- Self request prevention.
- Friend request accept/reject.
- Friend ranking includes accepted friends only.
- Public crew search and free join.
- Crew contribution rejects runs before membership start.
- Run save contribution applies to the selected crew.
- Weekly and monthly season score calculation.
- Maintenance penalty affects score, not territory geometry.

Flutter tests should cover:

- Social tab loading, empty, and error states.
- Friend code search result states.
- Friend request list actions.
- Crew search and joined state rendering.
- Crew detail ranking rendering.
- Run save crew selector default and change behavior.
- Map layer selection state.

Actual Google Map rendering, location permission behavior, and real run flows still need device or integration testing.

## Out Of Scope

- Activity feed.
- Comments.
- Likes or cheering.
- Chat.
- Crew notices.
- Crew owner/operator management.
- Crew approval workflow.
- Pace or goal based crew matching.
- Private map sharing settings.
- Strong territory decay, neutralization, or territory deletion.

