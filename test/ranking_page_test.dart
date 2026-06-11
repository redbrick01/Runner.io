import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/ranking_page.dart';
import 'package:runner_flutter/services/crew_service.dart';
import 'package:runner_flutter/services/social_service.dart';

void main() {
  Widget buildSubject() {
    return const MaterialApp(home: RankingPage());
  }

  group('RankingPage', () {
    testWidgets('shows loading and then an empty state when rankings fail', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('데이터가 없습니다.'), findsOneWidget);
      expect(find.text('일'), findsOneWidget);
      expect(find.text('주'), findsOneWidget);
      expect(find.text('월'), findsOneWidget);
      expect(find.text('년'), findsOneWidget);
      expect(find.text('전체'), findsOneWidget);
    });

    testWidgets(
      'keeps the page stable when changing range tabs after failure',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('주'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('월'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('전체'));
        await tester.pumpAndSettle();

        expect(find.byType(RankingPage), findsOneWidget);
        expect(find.text('데이터가 없습니다.'), findsOneWidget);
        expect(find.text('전체 기간'), findsOneWidget);
      },
    );

    testWidgets('shows friend rankings for friend scope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RankingPage(
            scope: RankingScope.friends,
            loadFriendRanking: ({required rangeType, anchorDate}) async =>
                FriendRanking(
                  range: SocialRange(
                    rangeType: rangeType,
                    anchorDate: '2026-06-05',
                    from: '2026-06-01',
                    to: '2026-06-07',
                  ),
                  results: const [
                    FriendRankingItem(
                      userId: 'self',
                      nickName: '나',
                      totalPoints: 42,
                      displayRank: 1,
                      isSelf: true,
                    ),
                    FriendRankingItem(
                      userId: 'friend-a',
                      nickName: '친구A',
                      totalPoints: 12,
                      displayRank: 2,
                      isSelf: false,
                    ),
                  ],
                ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('친구 랭킹'), findsOneWidget);
      expect(find.text('나'), findsWidgets);
      expect(find.text('일'), findsNothing);
      expect(find.text('년'), findsNothing);
      expect(find.text('주'), findsOneWidget);
      expect(find.text('월'), findsOneWidget);
      expect(find.text('전체'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(find.text('친구A'), findsOneWidget);
    });

    testWidgets('shows crew rankings for crew scope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RankingPage(
            scope: RankingScope.crew,
            loadCrewRanking:
                ({required seasonType, anchorDate, limit = 100}) async =>
                    CrewRanking(
                      season: CrewSeason(
                        seasonType: seasonType,
                        anchorDate: '2026-06-05',
                        from: '2026-06-01',
                        to: '2026-06-07',
                      ),
                      crews: const [
                        CrewSummary(
                          id: 'crew-1',
                          name: '강남러너스',
                          memberCount: 4,
                          seasonScore: 88,
                          cumulativeAreaM2: 1200000,
                          isJoined: true,
                          isDefaultContribution: true,
                          displayRank: 1,
                        ),
                      ],
                    ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('크루 랭킹'), findsOneWidget);
      expect(find.text('강남러너스'), findsOneWidget);
      expect(find.text('88 P'), findsOneWidget);
      expect(find.text('일'), findsNothing);
      expect(find.text('년'), findsNothing);
    });
  });
}
