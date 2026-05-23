import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/run_result_page.dart';

void main() {
  Map<String, dynamic> runData({
    Object? pathGeom,
    Object? loopGeom,
    List<Map<String, dynamic>> splits = const [],
  }) {
    return {
      'created_at': '2026-05-24T01:02:03Z',
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
