import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/point_history_page.dart';

void main() {
  Widget buildSubject() {
    return const MaterialApp(home: PointHistoryPage());
  }

  group('PointHistoryPage', () {
    testWidgets(
      'shows loading and then an empty state when point history fails',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('내역이 없습니다.'), findsOneWidget);
      },
    );
  });
}
