import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/social_page.dart';
import 'package:runner_flutter/services/crew_service.dart';
import 'package:runner_flutter/services/social_service.dart';

void main() {
  const friend = FriendProfile(
    userId: 'friend-1',
    nickName: '친구러너',
    friendCode: 'FRIEND01',
  );
  const crew = CrewSummary(
    id: 'crew-1',
    name: '강남 러너스',
    region: '강남',
    memberCount: 12,
    seasonScore: 245.5,
    cumulativeAreaM2: 320000,
    isJoined: true,
    isDefaultContribution: true,
    displayRank: 1,
  );
  const nextCrew = CrewSummary(
    id: 'crew-2',
    name: '서초 러너스',
    region: '서초',
    memberCount: 8,
    seasonScore: 120,
    cumulativeAreaM2: 180000,
    isJoined: false,
    isDefaultContribution: false,
    displayRank: 2,
  );

  Widget buildSubject({
    Future<List<CrewSummary>> Function()? loadMyCrews,
    Future<List<CrewSummary>> Function({
      String? query,
      String? region,
      CrewSort sort,
      int limit,
    })?
    searchCrews,
    Future<CrewDetail> Function(
      String crewId, {
      String seasonType,
      DateTime? anchorDate,
      int memberLimit,
    })?
    loadCrewDetail,
    Future<CrewMutationResult> Function(String crewId)? leaveCrew,
  }) {
    return MaterialApp(
      home: SocialPage(
        loadFriendCode: () async => 'AB12CD34',
        lookupFriendCode: (_) async => friend,
        sendFriendRequest: (_) async => FriendRequestResult(
          friendshipId: 'friendship-1',
          status: 'pending',
          addressee: friend,
        ),
        loadIncomingRequests: () async => [
          IncomingFriendRequest(
            friendshipId: 'request-1',
            createdAt: DateTime(2026, 6, 1),
            requester: friend,
          ),
        ],
        respondToFriendRequest: (_, _) async => const FriendResponseResult(
          friendshipId: 'request-1',
          status: 'accepted',
        ),
        loadFriends: () async => [friend],
        loadFriendRanking: ({required rangeType, anchorDate}) async =>
            FriendRanking(
              range: const SocialRange(
                rangeType: 'week',
                anchorDate: '2026-06-01',
                from: '2026-06-01',
                to: '2026-06-07',
              ),
              results: [
                const FriendRankingItem(
                  userId: 'me',
                  nickName: '나',
                  totalPoints: 300,
                  displayRank: 1,
                  isSelf: true,
                ),
                const FriendRankingItem(
                  userId: 'friend-1',
                  nickName: '친구러너',
                  totalPoints: 200,
                  displayRank: 2,
                  isSelf: false,
                ),
              ],
            ),
        loadMyCrews: loadMyCrews ?? () async => [crew],
        searchCrews:
            searchCrews ??
            ({query, region, sort = CrewSort.score, limit = 20}) async => [
              crew,
            ],
        loadCrewRanking:
            ({required seasonType, anchorDate, limit = 100}) async =>
                CrewRanking(
                  season: const CrewSeason(
                    seasonType: 'week',
                    anchorDate: '2026-06-01',
                    from: '2026-06-01',
                    to: '2026-06-07',
                  ),
                  crews: [crew],
                ),
        loadCrewDetail:
            loadCrewDetail ??
            (
              crewId, {
              seasonType = 'week',
              anchorDate,
              memberLimit = 50,
            }) async => CrewDetail(
              season: const CrewSeason(
                seasonType: 'week',
                anchorDate: '2026-06-01',
                from: '2026-06-01',
                to: '2026-06-07',
              ),
              crew: crewId == nextCrew.id ? nextCrew : crew,
              canViewMembers: true,
              members: const [
                CrewMemberContribution(
                  userId: 'friend-1',
                  nickName: '친구러너',
                  contributionScore: 80,
                  contributionAreaM2: 120000,
                  displayRank: 1,
                ),
              ],
            ),
        joinCrew: (_) async => CrewMutationResult(status: 'joined', crew: crew),
        leaveCrew:
            leaveCrew ??
            (_) async => CrewMutationResult(status: 'left', crew: crew),
        setDefaultCrew: (_) async =>
            CrewMutationResult(status: 'default_set', crew: crew),
      ),
    );
  }

  group('SocialPage', () {
    testWidgets('renders friends and crews MVP sections', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      expect(find.text('소셜'), findsOneWidget);
      expect(find.text('친구'), findsOneWidget);
      expect(find.text('크루'), findsOneWidget);
      expect(find.text('내 친구 코드'), findsOneWidget);
      expect(find.text('AB12CD34'), findsOneWidget);
      expect(find.text('받은 친구 요청'), findsOneWidget);
      expect(find.text('친구 목록'), findsOneWidget);
      expect(find.text('친구 랭킹'), findsOneWidget);

      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle();

      expect(find.text('내 크루'), findsOneWidget);
      expect(find.text('공개 크루 찾기'), findsOneWidget);
      expect(find.text('크루 랭킹'), findsOneWidget);
      expect(find.text('강남 러너스'), findsWidgets);
      expect(find.text('기본'), findsWidgets);
    });

    testWidgets('can lookup friend and send request', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'friend01');
      await tester.tap(find.text('조회'));
      await tester.pumpAndSettle();

      expect(find.text('친구러너님을 찾았습니다.'), findsOneWidget);

      await tester.tap(find.text('요청'));
      await tester.pumpAndSettle();

      expect(find.text('친구 요청을 보냈습니다.'), findsWidgets);
    });

    testWidgets('moves crew detail after leaving selected crew', (
      tester,
    ) async {
      var loadCount = 0;
      final loadedDetails = <String>[];

      await tester.pumpWidget(
        buildSubject(
          loadMyCrews: () async {
            loadCount += 1;
            return loadCount == 1 ? [crew] : const <CrewSummary>[];
          },
          searchCrews:
              ({query, region, sort = CrewSort.score, limit = 20}) async =>
                  loadCount == 1 ? [crew, nextCrew] : [nextCrew],
          loadCrewDetail:
              (
                crewId, {
                seasonType = 'week',
                anchorDate,
                memberLimit = 50,
              }) async {
                loadedDetails.add(crewId);
                return CrewDetail(
                  season: const CrewSeason(
                    seasonType: 'week',
                    anchorDate: '2026-06-01',
                    from: '2026-06-01',
                    to: '2026-06-07',
                  ),
                  crew: crewId == nextCrew.id ? nextCrew : crew,
                  canViewMembers: true,
                  members: const [],
                );
              },
          leaveCrew: (_) async =>
              const CrewMutationResult(status: 'left', crew: crew),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle();
      expect(loadedDetails.last, crew.id);

      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();

      expect(loadedDetails.last, nextCrew.id);
      expect(find.text('서초 러너스'), findsWidgets);
    });
  });
}
