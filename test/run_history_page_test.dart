import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/run_history_page.dart';

void main() {
  Widget buildSubject() {
    return const MaterialApp(home: RunHistoryPage());
  }

  group('RunHistoryPage', () {
    testWidgets('shows loading and then an empty state when history fails', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('러닝 통계'), findsOneWidget);
      expect(find.text('러닝 기록이 없습니다.'), findsOneWidget);
    });
  });
}
