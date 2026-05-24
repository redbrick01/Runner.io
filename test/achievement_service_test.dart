import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/services/achievement_service.dart';
import 'package:runner_flutter/services/run_history_service.dart';
import 'package:runner_flutter/services/user_profile_store.dart';

void main() {
  const service = AchievementService();

  RunHistoryEntry entry({
    required String startedAt,
    required double distance,
    required int duration,
    double point = 0,
    double area = 0,
    double? avgPace,
  }) {
    return RunHistoryEntry.fromMap({
      'started_at': startedAt,
      'distance': distance,
      'duration': duration,
      'point': point,
      'avg_pace': avgPace ?? (distance > 0 ? duration / (distance / 1000) : 0),
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

  Achievement findById(List<Achievement> achievements, String id) {
    return achievements.firstWhere((item) => item.id == id);
  }

  group('AchievementService', () {
    test('returns all MVP badges as unachieved for empty entries', () {
      final achievements = service.buildAchievements(entries: const []);

      expect(achievements, hasLength(8));
      expect(achievements.every((item) => !item.isAchieved), isTrue);
      expect(findById(achievements, 'first_run').progressValue, 0);
    });

    test('marks first run and first 5km from one long entry', () {
      final achievements = service.buildAchievements(
        entries: [
          entry(
            startedAt: '2026-05-24T09:00:00',
            distance: 5200,
            duration: 1800,
          ),
        ],
      );

      expect(findById(achievements, 'first_run').isAchieved, isTrue);
      expect(findById(achievements, 'first_5km').isAchieved, isTrue);
      expect(findById(achievements, 'total_100km').isAchieved, isFalse);
    });

    test('calculates total 100km progress and achievement date', () {
      final achievements = service.buildAchievements(
        entries: List.generate(10, (index) {
          return entry(
            startedAt:
                '2026-05-${(index + 1).toString().padLeft(2, '0')}T09:00:00',
            distance: 10000,
            duration: 3600,
          );
        }),
      );

      final badge = findById(achievements, 'total_100km');
      expect(badge.isAchieved, isTrue);
      expect(badge.progressValue, 100000);
      expect(badge.achievedAt?.day, 10);
    });

    test('detects seven day streak and ignores duplicate same-day runs', () {
      final entries = [
        entry(startedAt: '2026-05-01T09:00:00', distance: 1000, duration: 300),
        entry(startedAt: '2026-05-01T18:00:00', distance: 1000, duration: 300),
        for (var day = 2; day <= 7; day++)
          entry(
            startedAt: '2026-05-${day.toString().padLeft(2, '0')}T09:00:00',
            distance: 1000,
            duration: 300,
          ),
      ];

      final achievements = service.buildAchievements(entries: entries);

      final badge = findById(achievements, 'seven_day_streak');
      expect(badge.isAchieved, isTrue);
      expect(badge.progressValue, 7);
    });

    test('does not mark seven day streak when a day is missing', () {
      final entries = [
        for (final day in [1, 2, 3, 5, 6, 7, 8])
          entry(
            startedAt: '2026-05-${day.toString().padLeft(2, '0')}T09:00:00',
            distance: 1000,
            duration: 300,
          ),
      ];

      final achievements = service.buildAchievements(entries: entries);

      final badge = findById(achievements, 'seven_day_streak');
      expect(badge.isAchieved, isFalse);
      expect(badge.progressValue, 4);
    });

    test('detects monthly 10 runs', () {
      final achievements = service.buildAchievements(
        entries: List.generate(10, (index) {
          return entry(
            startedAt:
                '2026-05-${(index + 1).toString().padLeft(2, '0')}T09:00:00',
            distance: 1000,
            duration: 300,
          );
        }),
      );

      final badge = findById(achievements, 'monthly_10_runs');
      expect(badge.isAchieved, isTrue);
      expect(badge.achievedAt?.day, 10);
    });

    test('detects personal best pace improvement', () {
      final achievements = service.buildAchievements(
        entries: [
          entry(
            startedAt: '2026-05-01T09:00:00',
            distance: 3000,
            duration: 1200,
          ),
          entry(
            startedAt: '2026-05-02T09:00:00',
            distance: 3000,
            duration: 900,
          ),
        ],
      );

      final badge = findById(achievements, 'best_pace');
      expect(badge.isAchieved, isTrue);
      expect(badge.displayValue, "5'00\"");
    });

    test('handles territory pioneer and ruler from profile area', () {
      final achievements = service.buildAchievements(
        entries: const [],
        profile: profile(area: 12000000),
      );

      expect(findById(achievements, 'territory_pioneer').isAchieved, isTrue);
      expect(findById(achievements, 'territory_ruler').isAchieved, isTrue);
    });

    test('ignores invalid pace values without crashing', () {
      final achievements = service.buildAchievements(
        entries: [
          entry(
            startedAt: '2026-05-01T09:00:00',
            distance: 0,
            duration: 0,
            avgPace: 0,
          ),
          entry(
            startedAt: '2026-05-02T09:00:00',
            distance: 1000,
            duration: 0,
            avgPace: 0,
          ),
        ],
      );

      expect(findById(achievements, 'best_pace').isAchieved, isFalse);
    });
  });
}
