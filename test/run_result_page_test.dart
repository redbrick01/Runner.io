import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/run_result_page.dart';
import 'package:runner_flutter/services/run_ai_report_service.dart';

void main() {
  Map<String, dynamic> runData({
    Object? id,
    Object? pathGeom,
    Object? loopGeom,
    List<Map<String, dynamic>> splits = const [],
  }) {
    return {
      'created_at': '2026-05-24T01:02:03Z',
      'id': id,
      'distance': 1234.0,
      'duration': 600,
      'point': 12.34,
      'avg_pace': 486.0,
      'calories': 88.8,
      'total_ascent': 17.5,
      'area': 4321.0,
      'path_geom': pathGeom,
      'loop_geom': loopGeom,
      'route_points': const [],
      'splits': splits,
    };
  }

  Widget buildSubject(Map<String, dynamic> data) {
    return MaterialApp(home: RunResultPage(runData: data));
  }

  group('RunResultPage', () {
    testWidgets('renders summary metrics when route data is unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(runData()));
      await tester.pump();

      expect(find.text('러닝 리포트'), findsOneWidget);
      expect(find.text('경로 데이터가 없습니다.'), findsOneWidget);
      expect(find.text('12.34 P'), findsWidgets);
      expect(find.text('주요 기록'), findsOneWidget);
      expect(find.text('거리'), findsOneWidget);
      expect(find.text('1.23'), findsOneWidget);
      expect(find.text('km'), findsWidgets);
      expect(find.text('시간'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('평균 페이스'), findsOneWidget);
      expect(find.textContaining("8'"), findsOneWidget);
      expect(find.text('칼로리'), findsOneWidget);
      expect(find.text('89'), findsOneWidget);
      expect(find.text('누적 상승'), findsOneWidget);
      expect(find.text('17.5 m'), findsOneWidget);
      expect(find.text('점령 면적'), findsOneWidget);
      expect(find.text('0.00 km²'), findsOneWidget);
      expect(find.text('확인'), findsOneWidget);
    });

    testWidgets('renders AI report when report data is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RunResultPage(
            runData: runData(id: 10),
            loadAiReport: (_) async => RunAiReport.fromMap({
              'run_id': 10,
              'summary': '오늘은 비슷한 기록보다 후반 페이스가 안정적이에요.',
              'improvements': ['초반 속도를 조금만 낮춰 보세요.'],
              'next_goal': {'label': '다음 3km 페이스 5초 단축'},
              'coaching_message': '이 흐름이면 다음 기록도 기대할 만해요.',
              'comparison': {'similar_run_count': 3},
              'status': 'completed',
              'model': 'gpt-5.4-mini',
            }),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('AI 러닝 분석'), findsOneWidget);
      expect(find.text('유사 3개'), findsOneWidget);
      expect(find.textContaining('후반 페이스'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('다음 3km'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('다음 기록'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('generates AI report only after tapping the action button', (
      tester,
    ) async {
      var generateCalls = 0;
      final completer = Completer<RunAiReport?>();

      await tester.pumpWidget(
        MaterialApp(
          home: RunResultPage(
            runData: runData(id: 11),
            loadAiReport: (_) async => null,
            generateAiReport: (_) {
              generateCalls += 1;
              return completer.future;
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(generateCalls, 0);
      expect(find.text('AI 분석하기'), findsOneWidget);

      await tester.ensureVisible(find.text('AI 분석하기'));
      await tester.pump();
      await tester.tap(find.text('AI 분석하기'));
      await tester.pump();

      expect(generateCalls, 1);
      expect(find.text('AI 분석을 생성 중입니다.'), findsOneWidget);

      completer.complete(
        RunAiReport.fromMap({
          'run_id': 11,
          'summary': 'AI 분석이 완료되었습니다.',
          'improvements': ['후반 페이스를 유지해 보세요.'],
          'next_goal': {'label': '다음 러닝 20분 유지'},
          'coaching_message': '좋은 기준 기록이에요.',
          'comparison': {'similar_run_count': 4},
          'status': 'completed',
          'model': 'gpt-5.4-mini',
        }),
      );
      await tester.pump();

      expect(find.text('AI 러닝 분석'), findsOneWidget);
      expect(find.textContaining('완료'), findsOneWidget);
      expect(find.text('AI 분석하기'), findsNothing);
    });

    testWidgets('renders split rows sorted by split index', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          runData(
            splits: [
              {
                'split_index': 2,
                'distance_m': 234.0,
                'duration_s': 120.0,
                'avg_pace_s_per_km': 512.8,
                'avg_speed_mps': 1.95,
              },
              {
                'split_index': 1,
                'distance_m': 1000.0,
                'duration_s': 480.0,
                'avg_pace_s_per_km': 480.0,
                'avg_speed_mps': 2.08,
              },
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('구간 페이스 (km)'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1.00km'), findsOneWidget);
      expect(find.text('0.23km'), findsOneWidget);
    });

    testWidgets('pops the page from the confirm action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RunResultPage(runData: runData()),
                    ),
                  );
                },
                child: const Text('Open Result'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Result'));
      await tester.pumpAndSettle();
      expect(find.byType(RunResultPage), findsOneWidget);

      await tester.ensureVisible(find.text('확인'));
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RunResultPage), findsNothing);
      expect(find.text('Open Result'), findsOneWidget);
    });
  });
}
