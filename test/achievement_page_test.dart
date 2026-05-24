import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/achievement_page.dart';
import 'package:runner_flutter/services/run_history_service.dart';
import 'package:runner_flutter/services/user_profile_store.dart';

void main() {
  RunHistoryEntry entry({
    required String startedAt,
    required double distance,
    required int duration,
    double area = 0,
  }) {
    return RunHistoryEntry.fromMap({
      'started_at': startedAt,
      'distance': distance,
      'duration': duration,
      'point': 0,
      'avg_pace': distance > 0 ? duration / (distance / 1000) : 0,
      'area': area,
    });
  }

  UserProfileSnapshot profile({double area = 0}) {
    return UserProfileSnapshot.fromResponseMap({
      'data': {
        'rank': 1,
        'area': area,
        'profile': {
          'id': 1,
          'nick_name': 'runner',
          'total_points': 100,
          'color_hex': '#007AFF',
          'user_id': 'user-1',
        },
      },
    });
  }

  Widget buildSubject({
    required Future<List<RunHistoryEntry>> Function() loadEntries,
    Future<UserProfileSnapshot?> Function()? loadProfile,
  }) {
    return MaterialApp(
      home: AchievementPage(
        loadEntries: loadEntries,
        loadProfile: loadProfile ?? () async => null,
      ),
    );
  }

  group('AchievementPage', () {
    testWidgets('shows badges and progress summary', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          loadEntries: () async => [
            entry(
              startedAt: '2026-05-24T09:00:00',
              distance: 5200,
              duration: 1800,
            ),
          ],
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('배지'), findsOneWidget);
      expect(find.text('업적 진행'), findsOneWidget);
      expect(find.text('2 / 8'), findsOneWidget);
      expect(find.text('첫 러닝'), findsOneWidget);
      expect(find.text('첫 5km'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('누적 100km'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('누적 100km'), findsOneWidget);
    });

    testWidgets('filters badges by category', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          loadEntries: () async => const [],
          loadProfile: () async => profile(area: 1200000),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('영토'));
      await tester.pumpAndSettle();

      expect(find.text('영토 개척자'), findsOneWidget);
      expect(find.text('지배자'), findsOneWidget);
      expect(find.text('첫 러닝'), findsNothing);
    });

    testWidgets('opens badge detail sheet', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          loadEntries: () async => [
            entry(
              startedAt: '2026-05-24T09:00:00',
              distance: 1000,
              duration: 360,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('첫 러닝'));
      await tester.pumpAndSettle();

      expect(find.text('러닝 기록을 처음 저장했습니다.'), findsOneWidget);
      expect(find.textContaining('달성 완료'), findsOneWidget);
    });
  });
}
