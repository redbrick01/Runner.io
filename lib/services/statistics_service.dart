import 'app_formatters.dart';
import 'run_history_service.dart';

enum StatisticsPeriod { week, month, all }

class StatisticsDayTotal {
  const StatisticsDayTotal({required this.date, required this.distanceMetres});

  final DateTime date;
  final double distanceMetres;
}

class StatisticsRecord {
  const StatisticsRecord({required this.label, required this.value});

  final String label;
  final String value;
}

class StatisticsSummary {
  const StatisticsSummary({
    required this.period,
    required this.entries,
    required this.totalDistanceMetres,
    required this.totalDurationSeconds,
    required this.totalPoints,
    required this.averagePaceSecondsPerKm,
    required this.recentDailyDistances,
    required this.personalRecords,
    required this.distanceChangeRatio,
  });

  final StatisticsPeriod period;
  final List<RunHistoryEntry> entries;
  final double totalDistanceMetres;
  final int totalDurationSeconds;
  final double totalPoints;
  final double averagePaceSecondsPerKm;
  final List<StatisticsDayTotal> recentDailyDistances;
  final List<StatisticsRecord> personalRecords;
  final double? distanceChangeRatio;

  int get runCount => entries.length;
  bool get isEmpty => entries.isEmpty;
}

class StatisticsService {
  const StatisticsService();

  StatisticsSummary buildSummary({
    required List<RunHistoryEntry> entries,
    required StatisticsPeriod period,
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();
    final sorted = [...entries]
      ..sort((a, b) {
        final aDate = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    final filtered = _filterEntries(sorted, period, anchor);
    final previous = _filterPreviousEntries(sorted, period, anchor);

    final totalDistance = _sumDistance(filtered);
    final totalDuration = filtered.fold<int>(
      0,
      (sum, entry) => sum + entry.durationSeconds,
    );
    final totalPoints = filtered.fold<double>(
      0,
      (sum, entry) => sum + entry.point,
    );
    final averagePace = totalDistance > 0
        ? totalDuration / (totalDistance / 1000)
        : 0.0;

    return StatisticsSummary(
      period: period,
      entries: filtered,
      totalDistanceMetres: totalDistance,
      totalDurationSeconds: totalDuration,
      totalPoints: totalPoints,
      averagePaceSecondsPerKm: averagePace,
      recentDailyDistances: _recentDailyDistances(sorted, anchor),
      personalRecords: _buildPersonalRecords(sorted),
      distanceChangeRatio: _distanceChangeRatio(
        currentDistance: totalDistance,
        previousDistance: _sumDistance(previous),
      ),
    );
  }

  List<RunHistoryEntry> _filterEntries(
    List<RunHistoryEntry> entries,
    StatisticsPeriod period,
    DateTime now,
  ) {
    if (period == StatisticsPeriod.all) {
      return entries;
    }
    final range = _currentRange(period, now);
    return entries
        .where((entry) {
          final startedAt = entry.startedAt?.toLocal();
          if (startedAt == null) return false;
          return !startedAt.isBefore(range.start) &&
              startedAt.isBefore(range.end);
        })
        .toList(growable: false);
  }

  List<RunHistoryEntry> _filterPreviousEntries(
    List<RunHistoryEntry> entries,
    StatisticsPeriod period,
    DateTime now,
  ) {
    if (period == StatisticsPeriod.all) {
      return const [];
    }
    final range = _previousRange(period, now);
    return entries
        .where((entry) {
          final startedAt = entry.startedAt?.toLocal();
          if (startedAt == null) return false;
          return !startedAt.isBefore(range.start) &&
              startedAt.isBefore(range.end);
        })
        .toList(growable: false);
  }

  _DateRange _currentRange(StatisticsPeriod period, DateTime now) {
    final local = now.toLocal();
    if (period == StatisticsPeriod.week) {
      final today = DateTime(local.year, local.month, local.day);
      final start = today.subtract(Duration(days: today.weekday - 1));
      return _DateRange(start, start.add(const Duration(days: 7)));
    }
    final start = DateTime(local.year, local.month);
    return _DateRange(start, DateTime(local.year, local.month + 1));
  }

  _DateRange _previousRange(StatisticsPeriod period, DateTime now) {
    final current = _currentRange(period, now);
    if (period == StatisticsPeriod.week) {
      final start = current.start.subtract(const Duration(days: 7));
      return _DateRange(start, current.start);
    }
    final start = DateTime(current.start.year, current.start.month - 1);
    return _DateRange(start, current.start);
  }

  List<StatisticsDayTotal> _recentDailyDistances(
    List<RunHistoryEntry> entries,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final totals = <DateTime, double>{
      for (var i = 0; i < 7; i++) start.add(Duration(days: i)): 0.0,
    };

    for (final entry in entries) {
      final startedAt = entry.startedAt?.toLocal();
      if (startedAt == null) continue;
      final day = DateTime(startedAt.year, startedAt.month, startedAt.day);
      if (totals.containsKey(day)) {
        totals[day] = totals[day]! + entry.distanceMetres;
      }
    }

    return totals.entries
        .map((entry) {
          return StatisticsDayTotal(
            date: entry.key,
            distanceMetres: entry.value,
          );
        })
        .toList(growable: false);
  }

  List<StatisticsRecord> _buildPersonalRecords(List<RunHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const [
        StatisticsRecord(label: '최장 거리', value: '-'),
        StatisticsRecord(label: '최고 페이스', value: '-'),
        StatisticsRecord(label: '최대 점령 면적', value: '-'),
      ];
    }

    final longestDistance = entries.reduce(
      (best, entry) =>
          entry.distanceMetres > best.distanceMetres ? entry : best,
    );
    final fastestEntries = entries
        .where((entry) {
          return entry.distanceMetres >= 100 && entry.durationSeconds > 0;
        })
        .toList(growable: false);
    final fastest = fastestEntries.isEmpty
        ? null
        : fastestEntries.reduce((best, entry) {
            final bestPace = _paceForEntry(best);
            final entryPace = _paceForEntry(entry);
            return entryPace < bestPace ? entry : best;
          });
    final largestArea = entries.reduce(
      (best, entry) => _areaMetres(entry) > _areaMetres(best) ? entry : best,
    );

    return [
      StatisticsRecord(
        label: '최장 거리',
        value: AppFormatters.distance(longestDistance.distanceMetres),
      ),
      StatisticsRecord(
        label: '최고 페이스',
        value: fastest == null
            ? '-'
            : AppFormatters.pace(_paceForEntry(fastest)),
      ),
      StatisticsRecord(
        label: '최대 점령 면적',
        value: AppFormatters.area(_areaMetres(largestArea)),
      ),
    ];
  }

  double _sumDistance(List<RunHistoryEntry> entries) {
    return entries.fold<double>(0, (sum, entry) => sum + entry.distanceMetres);
  }

  double _paceForEntry(RunHistoryEntry entry) {
    if (entry.distanceMetres <= 0 || entry.durationSeconds <= 0) {
      return double.infinity;
    }
    return entry.durationSeconds / (entry.distanceMetres / 1000);
  }

  double _areaMetres(RunHistoryEntry entry) {
    final value = entry.raw['area'] ?? entry.raw['area_m2'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double? _distanceChangeRatio({
    required double currentDistance,
    required double previousDistance,
  }) {
    if (previousDistance <= 0) {
      return currentDistance > 0 ? 1.0 : null;
    }
    return (currentDistance - previousDistance) / previousDistance;
  }
}

class _DateRange {
  const _DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}
