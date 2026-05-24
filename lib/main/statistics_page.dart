import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../design/app_design.dart';
import '../services/run_ai_report_service.dart';
import '../services/run_history_service.dart';
import '../services/statistics_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    this.loadEntries,
    this.loadLatestAiReport,
    this.now,
  });

  final Future<List<RunHistoryEntry>> Function()? loadEntries;
  final Future<RunAiReport?> Function()? loadLatestAiReport;
  final DateTime? now;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  static const _statisticsService = StatisticsService();

  StatisticsPeriod _period = StatisticsPeriod.week;
  List<RunHistoryEntry> _entries = const [];
  RunAiReport? _latestAiReport;
  bool _isAiReportLoading = false;
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
      await _loadLatestAiReport();
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

  Future<void> _loadLatestAiReport() async {
    setState(() {
      _isAiReportLoading = true;
    });
    try {
      final loader =
          widget.loadLatestAiReport ??
          () => RunAiReportService.instance.fetchLatestReport();
      final report = await loader();
      if (!mounted) return;
      setState(() {
        _latestAiReport = report;
        _isAiReportLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _latestAiReport = null;
        _isAiReportLoading = false;
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
                padding: AppSpacing.page,
                children: [
                  if (_errorMessage != null)
                    AppNoticeCard(
                      icon: Icons.cloud_off_rounded,
                      title: _errorMessage!,
                      subtitle: '잠시 후 다시 시도해 주세요.',
                    ),
                  _PeriodSelector(
                    selected: _period,
                    onChanged: (period) => setState(() => _period = period),
                  ),
                  AppSpacing.gap,
                  if (summary.isEmpty)
                    const AppNoticeCard(
                      icon: Icons.directions_run_rounded,
                      title: '아직 표시할 러닝 기록이 없습니다.',
                      subtitle: '러닝을 저장하면 이곳에서 성장 추이를 볼 수 있습니다.',
                    )
                  else
                    _SummarySection(summary: summary),
                  AppSpacing.gap,
                  _AiReportSection(
                    report: _latestAiReport,
                    isLoading: _isAiReportLoading,
                  ),
                  AppSpacing.gap,
                  _DistanceChart(days: summary.recentDailyDistances),
                  AppSpacing.gap,
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
    return AppSegmentedControl<StatisticsPeriod>(
      value: selected,
      onChanged: onChanged,
      options: const [
        AppSegmentOption(value: StatisticsPeriod.week, label: '주간'),
        AppSegmentOption(value: StatisticsPeriod.month, label: '월간'),
        AppSegmentOption(value: StatisticsPeriod.all, label: '전체'),
      ],
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
            AppMetricCard(
              label: '총 거리',
              value: _formatDistance(summary.totalDistanceMetres),
              icon: Icons.route_rounded,
            ),
            AppMetricCard(
              label: '러닝 시간',
              value: _formatDuration(summary.totalDurationSeconds),
              icon: Icons.timer_rounded,
            ),
            AppMetricCard(
              label: '러닝 횟수',
              value: '${summary.runCount}회',
              icon: Icons.repeat_rounded,
            ),
            AppMetricCard(
              label: '평균 페이스',
              value: _formatPace(summary.averagePaceSecondsPerKm),
              icon: Icons.speed_rounded,
            ),
            AppMetricCard(
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
    return AppSurface(
      color: AppColors.primarySoft,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.primary,
            ),
          ),
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

class _AiReportSection extends StatelessWidget {
  const _AiReportSection({required this.report, required this.isLoading});

  final RunAiReport? report;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final currentReport = report;
    if (isLoading && currentReport == null) {
      return const AppSurface(
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'AI 분석을 불러오는 중입니다.',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (currentReport == null) {
      return const AppNoticeCard(
        icon: Icons.auto_awesome_rounded,
        title: 'AI 분석 리포트가 아직 없습니다.',
        subtitle: '러닝을 저장하면 비슷한 과거 기록과 비교해 코칭을 보여줍니다.',
        margin: EdgeInsets.zero,
      );
    }

    return AppSurface(
      color: AppColors.primarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '최근 AI 분석',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (currentReport.similarRunCount > 0)
                Text(
                  '유사 ${currentReport.similarRunCount}개',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            currentReport.summary,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _AiReportLine(
            icon: Icons.flag_rounded,
            label: '다음 목표',
            value: currentReport.nextGoalLabel,
          ),
          const SizedBox(height: 8),
          _AiReportLine(
            icon: Icons.chat_bubble_rounded,
            label: '코칭',
            value: currentReport.coachingMessage,
          ),
        ],
      ),
    );
  }
}

class _AiReportLine extends StatelessWidget {
  const _AiReportLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  height: 1.32,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
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

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('최근 7일 거리', style: AppTextStyles.sectionTitle),
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
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('개인 최고 기록', style: AppTextStyles.sectionTitle),
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
