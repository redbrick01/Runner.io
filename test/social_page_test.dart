import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/social_page.dart';
import 'package:runner_flutter/services/crew_service.dart';
import 'package:runner_flutter/services/social_service.dart';
import 'package:runner_flutter/services/supabase_api.dart';

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
    Future<String> Function()? loadFriendCode,
    Future<FriendRequestResult> Function(String code)? sendFriendRequest,
    Future<FriendResponseResult> Function(
      String friendshipId,
      FriendResponse response,
    )?
    respondToFriendRequest,
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
    Future<CrewMutationResult> Function({
      required String name,
      String? description,
      String? region,
      String? colorHex,
    })?
    createCrew,
    Future<CrewMutationResult> Function(String crewId)? leaveCrew,
  }) {
    return MaterialApp(
      home: SocialPage(
        loadFriendCode: loadFriendCode ?? () async => 'AB12CD34',
        lookupFriendCode: (_) async => friend,
        sendFriendRequest:
            sendFriendRequest ??
            (_) async => FriendRequestResult(
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
        respondToFriendRequest:
            respondToFriendRequest ??
            (_, _) async => const FriendResponseResult(
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
        createCrew:
            createCrew ??
            ({required name, description, region, colorHex}) async =>
                CrewMutationResult(status: 'created', crew: crew),
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
      expect(find.text('관계와 영토 경쟁'), findsNothing);
      expect(find.text('친구 1명'), findsNothing);
      expect(find.text('참여 크루 1개'), findsNothing);
      expect(find.byTooltip('친구 관리'), findsOneWidget);
      expect(find.byTooltip('내 친구 코드'), findsNothing);
      expect(find.byTooltip('친구 검색'), findsNothing);
      expect(find.byTooltip('친구 요청'), findsNothing);
      expect(find.text('내 친구 코드'), findsNothing);
      expect(find.text('AB12CD34'), findsNothing);
      expect(find.text('받은 친구 요청'), findsNothing);
      expect(find.text('친구 목록'), findsOneWidget);
      expect(find.text('친구 랭킹'), findsOneWidget);

      await tester.tap(find.byTooltip('친구 관리'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '친구 관리'), findsOneWidget);
      expect(find.text('내 친구 코드'), findsWidgets);
      expect(find.text('AB12CD34'), findsOneWidget);
      expect(find.text('받은 친구 요청'), findsOneWidget);
      expect(find.text('친구러너'), findsWidgets);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle();

      expect(find.text('크루 영토 경쟁'), findsNothing);
      expect(find.byTooltip('크루 관리'), findsOneWidget);
      expect(find.byTooltip('내 크루'), findsNothing);
      expect(find.byTooltip('크루 만들기'), findsNothing);
      expect(find.byTooltip('공개 크루 찾기'), findsNothing);
      expect(find.text('내 크루'), findsNothing);
      expect(find.text('크루 만들기'), findsNothing);
      expect(find.text('공개 크루 찾기'), findsNothing);
      expect(find.text('크루 랭킹'), findsOneWidget);
      expect(find.text('강남 러너스'), findsWidgets);
      expect(find.text('기본'), findsWidgets);

      await tester.tap(find.byTooltip('크루 관리'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '크루 관리'), findsOneWidget);
      expect(find.text('내 크루'), findsWidgets);
      expect(find.text('크루 만들기'), findsWidgets);
      expect(find.text('공개 크루 찾기'), findsWidgets);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
    });

    testWidgets('can lookup friend and send request', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('친구 관리'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '친구 관리'), findsOneWidget);

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

      await tester.tap(find.byTooltip('크루 관리'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '크루 관리'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();

      expect(loadedDetails.last, nextCrew.id);
      expect(find.text('서초 러너스'), findsWidgets);
    });

    testWidgets('can create crew from crews tab', (tester) async {
      var createdName = '';
      var createdRegion = '';

      await tester.pumpWidget(
        buildSubject(
          createCrew: ({required name, description, region, colorHex}) async {
            createdName = name;
            createdRegion = region ?? '';
            return const CrewMutationResult(status: 'created', crew: crew);
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('크루 관리'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, '크루 관리'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '크루명'), '한강 러너스');
      await tester.enterText(find.widgetWithText(TextField, '지역'), '한강');
      await tester.tap(find.text('생성'));
      await tester.pumpAndSettle();

      expect(createdName, '한강 러너스');
      expect(createdRegion, '한강');
      expect(find.text('크루를 만들었습니다.'), findsOneWidget);
    });

    testWidgets('explains missing friend code before copy is available', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(loadFriendCode: () async => ''));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('친구 관리'));
      await tester.pumpAndSettle();

      expect(find.text('발급 전'), findsOneWidget);
      expect(find.text('친구 코드를 불러오면 복사할 수 있어요.'), findsOneWidget);
      final copyButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.copy_rounded),
      );
      expect(copyButton.onPressed, isNull);
    });

    testWidgets('shows actionable social load errors', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          loadFriendCode: () async =>
              throw Exception('Supabase configuration is missing'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('소셜 서버 설정이 없어 정보를 불러올 수 없습니다.'), findsOneWidget);
    });

    testWidgets('shows actionable friend request errors', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          sendFriendRequest: (_) async =>
              throw Exception('SocketException: connection failed'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('친구 관리'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'friend01');
      await tester.tap(find.text('요청'));
      await tester.pumpAndSettle();

      expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
    });

    testWidgets('shows actionable friend response errors', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          respondToFriendRequest: (_, _) async =>
              throw const ApiException('Missing access token', statusCode: 401),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('친구 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수락'));
      await tester.pumpAndSettle();

      expect(find.text('로그인이 필요합니다. 다시 로그인해 주세요.'), findsOneWidget);
    });

    testWidgets('keeps crew form values and shows duplicate name errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          createCrew: ({required name, description, region, colorHex}) async {
            throw const ApiException(
              '이미 사용 중인 크루명입니다.',
              statusCode: 409,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('크루 관리'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '크루명'), '한강 러너스');
      await tester.enterText(find.widgetWithText(TextField, '지역'), '한강');
      await tester.tap(find.text('생성'));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 크루명입니다.'), findsOneWidget);
      expect(find.text('한강 러너스'), findsOneWidget);
      expect(find.text('한강'), findsOneWidget);
    });
  });
}
