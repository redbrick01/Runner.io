import 'dart:math' as math;

import 'run_history_service.dart';
import 'user_profile_store.dart';

enum AchievementCategory { start, distance, streak, growth, territory, habit }

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.conditionText,
    required this.isAchieved,
    required this.progressValue,
    required this.targetValue,
    required this.iconType,
    this.achievedAt,
    this.displayValue,
  });

  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final String conditionText;
  final bool isAchieved;
  final double progressValue;
  final double targetValue;
  final DateTime? achievedAt;
  final String iconType;
  final String? displayValue;

  double get progressRatio {
    if (targetValue <= 0) return isAchieved ? 1.0 : 0.0;
    return (progressValue / targetValue).clamp(0.0, 1.0);
  }
}

class AchievementService {
  const AchievementService({
    this.firstFiveKmMetres = 5000,
    this.totalDistanceTargetMetres = 100000,
    this.monthlyRunTarget = 10,
    this.streakTargetDays = 7,
    this.rulerAreaTargetM2 = 10000000,
  });

  final double firstFiveKmMetres;
  final double totalDistanceTargetMetres;
  final int monthlyRunTarget;
  final int streakTargetDays;
  final double rulerAreaTargetM2;

  List<Achievement> buildAchievements({
    required List<RunHistoryEntry> entries,
    UserProfileSnapshot? profile,
    DateTime? now,
  }) {
    final sorted = [...entries]
      ..sort((a, b) {
        final aDate = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    final runCount = sorted.length;
    final longestDistance = _longestDistance(sorted);
    final totalDistance = _totalDistance(sorted);
    final streak = _longestStreak(sorted);
    final monthly = _maxMonthlyRuns(sorted);
    final bestPace = _bestPaceAchievement(sorted);
    final capturedRuns = sorted.where((entry) => _areaM2(entry) > 0).length;
    final profileArea = profile?.area ?? 0;
    final fallbackArea = sorted.fold<double>(
      0,
      (sum, entry) => sum + math.max(0, _areaM2(entry)),
    );
    final territoryArea = math.max(profileArea, fallbackArea);
    final hasTerritory = territoryArea > 0 || capturedRuns > 0;

    return [
      Achievement(
        id: 'first_run',
        title: '첫 러닝',
        description: '러닝 기록을 처음 저장했습니다.',
        category: AchievementCategory.start,
        conditionText: '러닝 1회 저장',
        isAchieved: runCount >= 1,
        progressValue: math.min(runCount, 1).toDouble(),
        targetValue: 1,
        achievedAt: sorted.isEmpty ? null : sorted.first.startedAt?.toLocal(),
        iconType: 'first_run',
        displayValue: '$runCount회',
      ),
      Achievement(
        id: 'first_5km',
        title: '첫 5km',
        description: '한 번에 5km 이상 달렸습니다.',
        category: AchievementCategory.distance,
        conditionText: '단일 러닝 5km 이상',
        isAchieved: longestDistance.value >= firstFiveKmMetres,
        progressValue: longestDistance.value,
        targetValue: firstFiveKmMetres,
        achievedAt: longestDistance.achievedAt,
        iconType: 'first_5km',
        displayValue: _formatDistance(longestDistance.value),
      ),
      Achievement(
        id: 'seven_day_streak',
        title: '7일 연속',
        description: '7일 연속으로 러닝 기록을 남겼습니다.',
        category: AchievementCategory.streak,
        conditionText: '서로 다른 날짜 7일 연속 러닝',
        isAchieved: streak.value >= streakTargetDays,
        progressValue: streak.value.toDouble(),
        targetValue: streakTargetDays.toDouble(),
        achievedAt: streak.achievedAt,
        iconType: 'seven_day_streak',
        displayValue: '${streak.value}일',
      ),
      Achievement(
        id: 'total_100km',
        title: '누적 100km',
        description: '누적 러닝 거리 100km를 달성했습니다.',
        category: AchievementCategory.growth,
        conditionText: '총 거리 100km 달성',
        isAchieved: totalDistance.value >= totalDistanceTargetMetres,
        progressValue: totalDistance.value,
        targetValue: totalDistanceTargetMetres,
        achievedAt: totalDistance.achievedAt,
        iconType: 'total_100km',
        displayValue: _formatDistance(totalDistance.value),
      ),
      Achievement(
        id: 'territory_pioneer',
        title: '영토 개척자',
        description: '첫 영토를 점령했습니다.',
        category: AchievementCategory.territory,
        conditionText: '영토 1개 이상 점령',
        isAchieved: hasTerritory,
        progressValue: hasTerritory ? 1 : 0,
        targetValue: 1,
        achievedAt: _firstTerritoryDate(sorted),
        iconType: 'territory_pioneer',
        displayValue: hasTerritory ? '점령 완료' : '미점령',
      ),
      Achievement(
        id: 'territory_ruler',
        title: '지배자',
        description: '누적 점령 면적 목표를 달성했습니다.',
        category: AchievementCategory.territory,
        conditionText: '누적 점령 면적 ${_formatArea(rulerAreaTargetM2)} 이상',
        isAchieved: territoryArea >= rulerAreaTargetM2,
        progressValue: territoryArea,
        targetValue: rulerAreaTargetM2,
        achievedAt: territoryArea >= rulerAreaTargetM2
            ? _firstTerritoryDate(sorted)
            : null,
        iconType: 'territory_ruler',
        displayValue: _formatArea(territoryArea),
      ),
      Achievement(
        id: 'best_pace',
        title: '스피드업',
        description: '평균 페이스 개인 최고 기록을 갱신했습니다.',
        category: AchievementCategory.growth,
        conditionText: '이전 기록보다 빠른 평균 페이스 달성',
        isAchieved: bestPace.isAchieved,
        progressValue: bestPace.isAchieved ? 1 : 0,
        targetValue: 1,
        achievedAt: bestPace.achievedAt,
        iconType: 'best_pace',
        displayValue: bestPace.value == null
            ? '-'
            : _formatPace(bestPace.value!),
      ),
      Achievement(
        id: 'monthly_10_runs',
        title: '꾸준함',
        description: '한 달에 10회 이상 러닝했습니다.',
        category: AchievementCategory.habit,
        conditionText: '한 달 10회 이상 러닝',
        isAchieved: monthly.value >= monthlyRunTarget,
        progressValue: monthly.value.toDouble(),
        targetValue: monthlyRunTarget.toDouble(),
        achievedAt: monthly.achievedAt,
        iconType: 'monthly_10_runs',
        displayValue: '${monthly.value}회',
      ),
    ];
  }

  _MetricResult _longestDistance(List<RunHistoryEntry> entries) {
    var value = 0.0;
    DateTime? achievedAt;
    for (final entry in entries) {
      if (entry.distanceMetres > value) {
        value = entry.distanceMetres;
        if (value >= firstFiveKmMetres) {
          achievedAt = entry.startedAt?.toLocal();
        }
      }
    }
    return _MetricResult(value: value, achievedAt: achievedAt);
  }

  _MetricResult _totalDistance(List<RunHistoryEntry> entries) {
    var value = 0.0;
    DateTime? achievedAt;
    for (final entry in entries) {
      value += math.max(0, entry.distanceMetres);
      if (achievedAt == null && value >= totalDistanceTargetMetres) {
        achievedAt = entry.startedAt?.toLocal();
      }
    }
    return _MetricResult(value: value, achievedAt: achievedAt);
  }

  _IntMetricResult _longestStreak(List<RunHistoryEntry> entries) {
    final days =
        entries
            .map((entry) => entry.startedAt?.toLocal())
            .whereType<DateTime>()
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort();
    if (days.isEmpty) return const _IntMetricResult(value: 0);

    var current = 1;
    var best = 1;
    DateTime? achievedAt;
    for (var i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      current = diff == 1 ? current + 1 : 1;
      if (current > best) best = current;
      if (achievedAt == null && current >= streakTargetDays) {
        achievedAt = days[i];
      }
    }
    return _IntMetricResult(value: best, achievedAt: achievedAt);
  }

  _IntMetricResult _maxMonthlyRuns(List<RunHistoryEntry> entries) {
    final grouped = <String, List<DateTime>>{};
    for (final entry in entries) {
      final startedAt = entry.startedAt?.toLocal();
      if (startedAt == null) continue;
      final key =
          '${startedAt.year}-${startedAt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <DateTime>[]).add(startedAt);
    }

    var best = 0;
    DateTime? achievedAt;
    for (final dates in grouped.values) {
      dates.sort();
      if (dates.length > best) best = dates.length;
      if (dates.length >= monthlyRunTarget) {
        final candidate = dates[monthlyRunTarget - 1];
        if (achievedAt == null || candidate.isBefore(achievedAt)) {
          achievedAt = candidate;
        }
      }
    }
    return _IntMetricResult(value: best, achievedAt: achievedAt);
  }

  _PaceMetricResult _bestPaceAchievement(List<RunHistoryEntry> entries) {
    final eligible = entries
        .where(
          (entry) => entry.distanceMetres >= 100 && entry.durationSeconds > 0,
        )
        .toList(growable: false);
    if (eligible.isEmpty) return const _PaceMetricResult(isAchieved: false);

    double? bestSoFar;
    double? bestOverall;
    DateTime? achievedAt;
    var improved = false;
    for (final entry in eligible) {
      final pace = _pace(entry);
      if (pace == null) continue;
      if (bestOverall == null || pace < bestOverall) {
        bestOverall = pace;
      }
      if (bestSoFar == null) {
        bestSoFar = pace;
        continue;
      }
      if (pace < bestSoFar) {
        improved = true;
        bestSoFar = pace;
        achievedAt ??= entry.startedAt?.toLocal();
      }
    }

    return _PaceMetricResult(
      isAchieved: improved,
      value: bestOverall,
      achievedAt: achievedAt,
    );
  }

  DateTime? _firstTerritoryDate(List<RunHistoryEntry> entries) {
    for (final entry in entries) {
      if (_areaM2(entry) > 0) return entry.startedAt?.toLocal();
    }
    return null;
  }

  double _areaM2(RunHistoryEntry entry) {
    final value = entry.raw['area'] ?? entry.raw['area_m2'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double? _pace(RunHistoryEntry entry) {
    if (entry.avgPaceSecondsPerKm > 0) return entry.avgPaceSecondsPerKm;
    if (entry.distanceMetres <= 0 || entry.durationSeconds <= 0) return null;
    return entry.durationSeconds / (entry.distanceMetres / 1000);
  }

  String _formatDistance(double metres) {
    final km = metres / 1000;
    return '${km.toStringAsFixed(km >= 10 ? 1 : 2)} km';
  }

  String _formatArea(double metres) {
    final km2 = metres / 1000000;
    return '${km2.toStringAsFixed(km2 >= 10 ? 1 : 2)} km²';
  }

  String _formatPace(double secondsPerKm) {
    if (!secondsPerKm.isFinite || secondsPerKm <= 0) return "-'--\"";
    final totalSeconds = secondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }
}

class _MetricResult {
  const _MetricResult({required this.value, this.achievedAt});

  final double value;
  final DateTime? achievedAt;
}

class _IntMetricResult {
  const _IntMetricResult({required this.value, this.achievedAt});

  final int value;
  final DateTime? achievedAt;
}

class _PaceMetricResult {
  const _PaceMetricResult({
    required this.isAchieved,
    this.value,
    this.achievedAt,
  });

  final bool isAchieved;
  final double? value;
  final DateTime? achievedAt;
}
