import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/services/run_history_service.dart';
import 'package:runner_flutter/services/statistics_service.dart';

void main() {
  const service = StatisticsService();
  final now = DateTime(2026, 5, 24, 12);

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

  group('StatisticsService', () {
    test('returns zero summary for empty entries', () {
      final summary = service.buildSummary(
        entries: const [],
        period: StatisticsPeriod.week,
        now: now,
      );

      expect(summary.isEmpty, isTrue);
      expect(summary.totalDistanceMetres, 0);
      expect(summary.totalDurationSeconds, 0);
      expect(summary.averagePaceSecondsPerKm, 0);
      expect(summary.recentDailyDistances, hasLength(7));
      expect(summary.personalRecords.map((record) => record.value), [
        '-',
        '-',
        '-',
      ]);
    });

    test('filters current week and calculates totals', () {
      final summary = service.buildSummary(
        entries: [
          entry(
            startedAt: '2026-05-24T09:00:00',
            distance: 3000,
            duration: 1200,
            point: 30,
          ),
          entry(
            startedAt: '2026-05-20T09:00:00',
            distance: 2000,
            duration: 900,
            point: 20,
          ),
          entry(
            startedAt: '2026-05-17T09:00:00',
            distance: 10000,
            duration: 3600,
            point: 100,
          ),
        ],
        period: StatisticsPeriod.week,
        now: now,
      );

      expect(summary.runCount, 2);
      expect(summary.totalDistanceMetres, 5000);
      expect(summary.totalDurationSeconds, 2100);
      expect(summary.totalPoints, 50);
      expect(summary.averagePaceSecondsPerKm, 420);
    });

    test('filters current month and calculates distance change ratio', () {
      final summary = service.buildSummary(
        entries: [
          entry(
            startedAt: '2026-05-03T09:00:00',
            distance: 6000,
            duration: 2400,
          ),
          entry(
            startedAt: '2026-04-28T09:00:00',
            distance: 3000,
            duration: 1200,
          ),
        ],
        period: StatisticsPeriod.month,
        now: now,
      );

      expect(summary.runCount, 1);
      expect(summary.totalDistanceMetres, 6000);
      expect(summary.distanceChangeRatio, 1.0);
    });

    test('builds recent 7 day distance totals', () {
      final summary = service.buildSummary(
        entries: [
          entry(
            startedAt: '2026-05-24T09:00:00',
            distance: 1000,
            duration: 300,
          ),
          entry(
            startedAt: '2026-05-24T18:00:00',
            distance: 1500,
            duration: 500,
          ),
          entry(
            startedAt: '2026-05-18T09:00:00',
            distance: 2000,
            duration: 700,
          ),
          entry(
            startedAt: '2026-05-17T09:00:00',
            distance: 9000,
            duration: 3000,
          ),
        ],
        period: StatisticsPeriod.all,
        now: now,
      );

      expect(summary.recentDailyDistances.first.distanceMetres, 2000);
      expect(summary.recentDailyDistances.last.distanceMetres, 2500);
    });

    test('builds personal records from all entries', () {
      final summary = service.buildSummary(
        entries: [
          entry(
            startedAt: '2026-05-24T09:00:00',
            distance: 5000,
            duration: 1500,
            area: 120000,
          ),
          entry(
            startedAt: '2026-05-23T09:00:00',
            distance: 8000,
            duration: 3200,
            area: 90000,
          ),
        ],
        period: StatisticsPeriod.week,
        now: now,
      );

      expect(summary.personalRecords[0].value, '8.00 km');
      expect(summary.personalRecords[1].value, "5'00\"");
      expect(summary.personalRecords[2].value, '0.12 km²');
    });
  });
}
