import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/statistics_page.dart';
import 'package:runner_flutter/services/run_history_service.dart';

void main() {
  RunHistoryEntry entry({
    required String startedAt,
    required double distance,
    required int duration,
    double point = 0,
    double area = 0,
  }) {
    return RunHistoryEntry.fromMap({
      'started_at': startedAt,
      'distance': distance,
      'duration': duration,
      'point': point,
      'avg_pace': distance > 0 ? duration / (distance / 1000) : 0,
      'area': area,
    });
  }

  Widget buildSubject({
    required Future<List<RunHistoryEntry>> Function() loadEntries,
  }) {
    return MaterialApp(
      home: StatisticsPage(
        now: DateTime(2026, 5, 24, 12),
        loadEntries: loadEntries,
        loadLatestAiReport: () async => null,
      ),
    );
  }

  group('StatisticsPage', () {
    testWidgets('shows an empty state when there are no entries', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(loadEntries: () async => const []));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('분석'), findsOneWidget);
      expect(find.text('아직 표시할 러닝 기록이 없습니다.'), findsOneWidget);
      expect(find.text('AI 분석 리포트가 아직 없습니다.'), findsOneWidget);
      expect(find.text('최근 7일 거리'), findsOneWidget);
      expect(find.text('개인 최고 기록'), findsOneWidget);
    });

    testWidgets('renders summary metrics and period switch', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          loadEntries: () async => [
            entry(
              startedAt: '2026-05-24T09:00:00',
              distance: 3000,
              duration: 1200,
              point: 30,
              area: 120000,
            ),
            entry(
              startedAt: '2026-05-20T09:00:00',
              distance: 2000,
              duration: 900,
              point: 20,
              area: 50000,
            ),
            entry(
              startedAt: '2026-04-20T09:00:00',
              distance: 1000,
              duration: 300,
              point: 10,
              area: 10000,
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('총 거리'), findsOneWidget);
      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('러닝 시간'), findsOneWidget);
      expect(find.text('35:00'), findsOneWidget);
      expect(find.text('러닝 횟수'), findsOneWidget);
      expect(find.text('2회'), findsOneWidget);
      expect(find.text('획득 포인트'), findsOneWidget);
      expect(find.text('50 P'), findsOneWidget);

      await tester.tap(find.text('월간'));
      await tester.pumpAndSettle();

      expect(find.text('이번 달 지난 기간보다 400% 더 달렸어요.'), findsOneWidget);
    });
  });
}
