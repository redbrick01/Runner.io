import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/run_history_service.dart';
import '../services/statistics_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, this.loadEntries, this.now});

  final Future<List<RunHistoryEntry>> Function()? loadEntries;
  final DateTime? now;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  static const _statisticsService = StatisticsService();

  StatisticsPeriod _period = StatisticsPeriod.week;
  List<RunHistoryEntry> _entries = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final loader =
          widget.loadEntries ??
          () => RunHistoryService.instance.fetchRunHistory(limit: 500);
      final entries = await loader();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _entries = const [];
        _errorMessage = '통계를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _statisticsService.buildSummary(
      entries: _entries,
      period: _period,
      now: widget.now,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '분석',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_errorMessage != null)
                    _NoticeCard(
                      icon: Icons.cloud_off_rounded,
                      title: _errorMessage!,
                      subtitle: '잠시 후 다시 시도해 주세요.',
                    ),
                  _PeriodSelector(
                    selected: _period,
                    onChanged: (period) => setState(() => _period = period),
                  ),
                  const SizedBox(height: 14),
                  if (summary.isEmpty)
                    const _NoticeCard(
                      icon: Icons.directions_run_rounded,
                      title: '아직 표시할 러닝 기록이 없습니다.',
                      subtitle: '러닝을 저장하면 이곳에서 성장 추이를 볼 수 있습니다.',
                    )
                  else
                    _SummarySection(summary: summary),
                  const SizedBox(height: 14),
                  _DistanceChart(days: summary.recentDailyDistances),
                  const SizedBox(height: 14),
                  _RecordsSection(records: summary.personalRecords),
                ],
              ),
            ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final StatisticsPeriod selected;
  final ValueChanged<StatisticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _PeriodButton(
            label: '주간',
            selected: selected == StatisticsPeriod.week,
            onTap: () => onChanged(StatisticsPeriod.week),
          ),
          _PeriodButton(
            label: '월간',
            selected: selected == StatisticsPeriod.month,
            onTap: () => onChanged(StatisticsPeriod.month),
          ),
          _PeriodButton(
            label: '전체',
            selected: selected == StatisticsPeriod.all,
            onTap: () => onChanged(StatisticsPeriod.all),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.secondaryText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});

  final StatisticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InsightCard(summary: summary),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _MetricCard(
              label: '총 거리',
              value: _formatDistance(summary.totalDistanceMetres),
              icon: Icons.route_rounded,
            ),
            _MetricCard(
              label: '러닝 시간',
              value: _formatDuration(summary.totalDurationSeconds),
              icon: Icons.timer_rounded,
            ),
            _MetricCard(
              label: '러닝 횟수',
              value: '${summary.runCount}회',
              icon: Icons.repeat_rounded,
            ),
            _MetricCard(
              label: '평균 페이스',
              value: _formatPace(summary.averagePaceSecondsPerKm),
              icon: Icons.speed_rounded,
            ),
            _MetricCard(
              label: '획득 포인트',
              value: _formatPoint(summary.totalPoints),
              icon: Icons.stars_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.summary});

  final StatisticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _insightText(summary),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _insightText(StatisticsSummary summary) {
    final label = switch (summary.period) {
      StatisticsPeriod.week => '이번 주',
      StatisticsPeriod.month => '이번 달',
      StatisticsPeriod.all => '전체 기간',
    };
    if (summary.period == StatisticsPeriod.all ||
        summary.distanceChangeRatio == null) {
      return '$label ${_formatDistance(summary.totalDistanceMetres)}를 달렸어요.';
    }
    final ratio = summary.distanceChangeRatio!;
    if (ratio >= 0) {
      return '$label 지난 기간보다 ${(ratio * 100).round()}% 더 달렸어요.';
    }
    return '$label 지난 기간보다 ${(-ratio * 100).round()}% 적게 달렸어요.';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistanceChart extends StatelessWidget {
  const _DistanceChart({required this.days});

  final List<StatisticsDayTotal> days;

  @override
  Widget build(BuildContext context) {
    final maxDistance = days.fold<double>(
      0,
      (max, day) => day.distanceMetres > max ? day.distanceMetres : max,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 7일 거리',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days
                  .map((day) {
                    final ratio = maxDistance <= 0
                        ? 0.0
                        : day.distanceMetres / maxDistance;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _shortDistance(day.distanceMetres),
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 18 + (90 * ratio),
                              decoration: BoxDecoration(
                                color: day.distanceMetres > 0
                                    ? AppColors.primary
                                    : AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _weekday(day.date),
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.records});

  final List<StatisticsRecord> records;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '개인 최고 기록',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...records.map((record) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      record.label,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    record.value,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDistance(double metres) {
  final km = metres / 1000;
  return '${km.toStringAsFixed(km >= 10 ? 1 : 2)} km';
}

String _formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatPace(double secondsPerKm) {
  if (!secondsPerKm.isFinite || secondsPerKm <= 0) return "-'--\"";
  final totalSeconds = secondsPerKm.round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
}

String _formatPoint(double point) {
  if (point == point.roundToDouble()) {
    return '${point.toInt()} P';
  }
  return '${point.toStringAsFixed(1)} P';
}

String _shortDistance(double metres) {
  if (metres <= 0) return '0';
  final km = metres / 1000;
  return km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
}

String _weekday(DateTime date) {
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  return labels[date.weekday - 1];
}
