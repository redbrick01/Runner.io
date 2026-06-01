import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/statistics_page.dart';
import 'package:runner_flutter/services/run_ai_report_service.dart';
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
    Future<RunAiReport?> Function()? loadLatestAiReport,
  }) {
    return MaterialApp(
      home: StatisticsPage(
        now: DateTime(2026, 5, 24, 12),
        loadEntries: loadEntries,
        loadLatestAiReport: loadLatestAiReport ?? () async => null,
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

    testWidgets('does not overflow on a narrow iPhone analysis layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildSubject(
          loadEntries: () async => [
            entry(
              startedAt: '2026-05-24T09:00:00',
              distance: 2020,
              duration: 112,
              point: 22.2,
              area: 370000,
            ),
            entry(
              startedAt: '2026-05-21T09:00:00',
              distance: 2100,
              duration: 140,
            ),
            entry(
              startedAt: '2026-05-20T09:00:00',
              distance: 1200,
              duration: 800,
            ),
          ],
          loadLatestAiReport: () async => const RunAiReport(
            runId: 1,
            summary:
                '이번 2.02km 러닝은 유사 기록 5회 평균보다 약간 더 빠른 편이었고, 오르막 부담이 있는 코스에서도 초반 페이스는 안정적이었습니다.',
            improvements: [],
            nextGoal: {'label': '고르기 2.1km 러닝'},
            coachingMessage: '좋아요! 오늘은 오르막이 있었는데도 초반 페이스가 잘 나왔어요.',
            comparison: {'similar_run_count': 5},
            status: 'completed',
            model: 'test',
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
