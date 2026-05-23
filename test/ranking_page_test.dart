import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/ranking_page.dart';

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
  });
}
