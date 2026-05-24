import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../design/app_design.dart';
import '../services/point_history_service.dart';
import '../services/run_history_service.dart';
import 'run_result_page.dart';

enum _PointRangeType { day, week, month, year }

class PointHistoryPage extends StatefulWidget {
  const PointHistoryPage({super.key});

  @override
  State<PointHistoryPage> createState() => _PointHistoryPageState();
}

class _PointHistoryPageState extends State<PointHistoryPage> {
  List<dynamic> _historyItems = [];
  bool _isLoading = true;
  _PointRangeType _rangeType = _PointRangeType.day;
  DateTime _anchorDate = DateTime.now();
  final Set<String> _expandedTerritoryGroupKeys = {};

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double _totalDeltaOf(List<dynamic> items) {
    return items.fold<double>(
      0,
      (sum, item) => sum + _asDouble(item['points_delta']),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchPointHistory();
  }

  String _rangeTypeToQueryValue(_PointRangeType type) {
    switch (type) {
      case _PointRangeType.day:
        return 'day';
      case _PointRangeType.week:
        return 'week';
      case _PointRangeType.month:
        return 'month';
      case _PointRangeType.year:
        return 'year';
    }
  }

  String _anchorDateKey(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _fetchPointHistory({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final items = await PointHistoryService.instance.fetchPointHistory(
        rangeType: _rangeTypeToQueryValue(_rangeType),
        anchorDate: _anchorDateKey(_anchorDate),
      );
      final sortedItems = [...items]
        ..sort((a, b) {
          final aTime =
              DateTime.tryParse((a['created_at'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              DateTime.tryParse((b['created_at'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      setState(() {
        _historyItems = sortedItems;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("포인트 내역 로드 에러: $e");
      setState(() => _isLoading = false);
    }
  }

  String _getEventTypeText(String eventType) {
    switch (eventType) {
      case 'run_created':
      case 'run-create':
      case 'run_create':
      case 'run_complete':
        return '러닝 완료';
      case 'territory_points':
      case 'territory-point':
      case 'territory_point':
      case 'territory_capture':
        return '영토 유지';
      case 'login_bonus':
        return '출석 보상';
      default:
        return eventType;
    }
  }

  IconData _getEventTypeIcon(String eventType) {
    switch (eventType) {
      case 'run_created':
      case 'run-create':
      case 'run_create':
        return Icons.directions_run_rounded;
      case 'run_complete':
        return Icons.directions_run;
      case 'territory_points':
      case 'territory-point':
      case 'territory_point':
        return Icons.outlined_flag_rounded;
      case 'territory_capture':
        return Icons.map;
      case 'login_bonus':
        return Icons.card_giftcard;
      default:
        return Icons.stars;
    }
  }

  Color _getEventTypeColor(String eventType) {
    switch (eventType) {
      case 'run_created':
      case 'run-create':
      case 'run_create':
      case 'run_complete':
        return AppColors.primary;
      case 'territory_points':
      case 'territory-point':
      case 'territory_point':
        return Colors.orangeAccent;
      case 'territory_capture':
        return Colors.indigo;
      case 'login_bonus':
        return Colors.orangeAccent;
      default:
        return Colors.blueGrey;
    }
  }

  bool _isRunPointEvent(String eventType) {
    return eventType == 'run_created' ||
        eventType == 'run-create' ||
        eventType == 'run_create' ||
        eventType == 'run_complete';
  }

  bool _isTerritoryMaintainEvent(String eventType) {
    return eventType == 'territory_points' ||
        eventType == 'territory-point' ||
        eventType == 'territory_point';
  }

  DateTime _normalizeAnchor(DateTime value, _PointRangeType type) {
    if (type == _PointRangeType.year) return DateTime(value.year, 1, 1);
    if (type == _PointRangeType.week) return _startOfWeek(value);
    if (type == _PointRangeType.month) {
      return DateTime(value.year, value.month, 1);
    }
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _startOfWeek(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    final diff = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: diff));
  }

  DateTime _todayAnchor(_PointRangeType type) {
    return _normalizeAnchor(DateTime.now(), type);
  }

  DateTime _shiftedAnchor(DateTime base, _PointRangeType type, int delta) {
    if (type == _PointRangeType.day) {
      return DateTime(base.year, base.month, base.day + delta);
    }
    if (type == _PointRangeType.week) {
      return _startOfWeek(base.add(Duration(days: 7 * delta)));
    }
    if (type == _PointRangeType.month) {
      return DateTime(base.year, base.month + delta, 1);
    }
    if (type == _PointRangeType.year) {
      return DateTime(base.year + delta, 1, 1);
    }
    return base;
  }

  bool _canShift(int delta) {
    if (delta < 0) return true;
    final next = _shiftedAnchor(
      _normalizeAnchor(_anchorDate, _rangeType),
      _rangeType,
      1,
    );
    final today = _todayAnchor(_rangeType);
    return !next.isAfter(today);
  }

  Future<void> _shiftRange(int delta) async {
    final current = _normalizeAnchor(_anchorDate, _rangeType);
    final next = _shiftedAnchor(current, _rangeType, delta > 0 ? 1 : -1);
    final today = _todayAnchor(_rangeType);
    if (next.isAfter(today)) return;
    setState(() => _anchorDate = next);
    await _fetchPointHistory(showLoading: true);
  }

  Future<void> _onRangeTypeChanged(_PointRangeType nextType) async {
    if (_rangeType == nextType) return;
    setState(() {
      _rangeType = nextType;
      _anchorDate = _normalizeAnchor(_anchorDate, nextType);
    });
    await _fetchPointHistory(showLoading: true);
  }

  List<dynamic> _visibleItems() {
    return _historyItems;
  }

  String _rangeLabel() {
    final y = _anchorDate.year.toString();
    final m = _anchorDate.month.toString().padLeft(2, '0');
    final d = _anchorDate.day.toString().padLeft(2, '0');
    if (_rangeType == _PointRangeType.day) return '$y.$m.$d';
    if (_rangeType == _PointRangeType.week) {
      final start = _startOfWeek(_anchorDate);
      final end = start.add(const Duration(days: 6));
      final sm = start.month.toString().padLeft(2, '0');
      final sd = start.day.toString().padLeft(2, '0');
      final em = end.month.toString().padLeft(2, '0');
      final ed = end.day.toString().padLeft(2, '0');
      return '${start.year}.$sm.$sd ~ $em.$ed';
    }
    if (_rangeType == _PointRangeType.month) return '$y.$m';
    return y;
  }

  Widget _buildRangeToggleBar() {
    return AppSegmentedControl<_PointRangeType>(
      value: _rangeType,
      onChanged: _onRangeTypeChanged,
      options: const [
        AppSegmentOption(value: _PointRangeType.day, label: '일'),
        AppSegmentOption(value: _PointRangeType.week, label: '주'),
        AppSegmentOption(value: _PointRangeType.month, label: '월'),
        AppSegmentOption(value: _PointRangeType.year, label: '년'),
      ],
    );
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  Future<void> _openRunReportFromPointItem(Map<String, dynamic> item) async {
    final pointCreatedAt = _parseDate(item['created_at']);
    final pointValue = _asDouble(item['points_delta']);

    try {
      final runs = await RunHistoryService.instance.fetchRunHistory(limit: 100);
      if (!mounted) return;
      if (runs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('연결된 러닝 기록을 찾지 못했습니다.')));
        return;
      }

      RunHistoryEntry? best;
      double bestScore = double.infinity;
      for (final run in runs) {
        final runCreatedAt =
            _parseDate(run.raw['created_at']) ??
            _parseDate(run.raw['ended_at']) ??
            _parseDate(run.raw['started_at']);
        final timeDiffSeconds = (runCreatedAt != null && pointCreatedAt != null)
            ? (runCreatedAt
                      .toUtc()
                      .difference(pointCreatedAt.toUtc())
                      .inSeconds)
                  .abs()
                  .toDouble()
            : 3600 * 24 * 365;
        final pointDiff = (run.point - pointValue).abs();
        final score = timeDiffSeconds + (pointDiff * 1800);
        if (score < bestScore) {
          bestScore = score;
          best = run;
        }
      }

      if (best == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('연결된 러닝 기록을 찾지 못했습니다.')));
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RunResultPage(runData: best!.raw),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('러닝 기록을 여는 중 오류가 발생했습니다.')));
      debugPrint('Run report open failed: $error');
    }
  }

  Widget _buildRangeNavigator() {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      radius: AppRadii.control,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.text,
            onPressed: _canShift(-1) ? () => _shiftRange(-1) : null,
          ),
          Expanded(
            child: Text(
              _rangeLabel(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.text,
            onPressed: _canShift(1) ? () => _shiftRange(1) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems();
    final displayItems = _buildDisplayItems(visibleItems);
    final runCompletedPoints = visibleItems.fold<double>(0.0, (sum, item) {
      final eventType = (item['event_type'] ?? '').toString();
      if (!_isRunPointEvent(eventType)) return sum;
      return sum + _asDouble(item['points_delta']);
    });
    final territoryMaintainPoints = visibleItems.fold<double>(0.0, (sum, item) {
      final eventType = (item['event_type'] ?? '').toString();
      if (!_isTerritoryMaintainEvent(eventType)) return sum;
      return sum + _asDouble(item['points_delta']);
    });
    final totalDelta = _totalDeltaOf(visibleItems);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyItems.isEmpty
          ? const Center(
              child: Text(
                "내역이 없습니다.",
                style: TextStyle(color: AppColors.secondaryText),
              ),
            )
          : GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 200) return;
                if (velocity < 0) {
                  _shiftRange(1);
                } else {
                  _shiftRange(-1);
                }
              },
              child: ListView(
                padding: AppSpacing.page,
                children: [
                  _buildRangeToggleBar(),
                  const SizedBox(height: 10),
                  _buildRangeNavigator(),
                  const SizedBox(height: 12),
                  _buildSummaryCard(
                    totalDelta: totalDelta,
                    runCompletedPoints: runCompletedPoints,
                    territoryMaintainPoints: territoryMaintainPoints,
                  ),
                  const SizedBox(height: 20),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.border,
                  ),
                  const SizedBox(height: 12),
                  if (visibleItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '선택한 기간에 내역이 없습니다.',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                    )
                  else
                    ...displayItems.map(_buildDisplayCard),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard({
    required double totalDelta,
    required double runCompletedPoints,
    required double territoryMaintainPoints,
  }) {
    final isPositive = totalDelta >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '합계',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                "${isPositive ? '+' : ''}${totalDelta.toStringAsFixed(1)} P",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isPositive ? AppColors.primary : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryIconCard(
                  icon: Icons.directions_run_rounded,
                  accentColor: AppColors.primary,
                  value: '+${runCompletedPoints.toStringAsFixed(1)} P',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryIconCard(
                  icon: Icons.outlined_flag_rounded,
                  accentColor: Colors.orangeAccent,
                  value: '+${territoryMaintainPoints.toStringAsFixed(1)} P',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_PointDisplayItem> _buildDisplayItems(List<dynamic> items) {
    final result = <_PointDisplayItem>[];
    final territoryBuffer = <Map<String, dynamic>>[];

    void flushTerritoryBuffer() {
      if (territoryBuffer.isEmpty) return;
      if (territoryBuffer.length == 1) {
        result.add(_PointDisplayItem.single(territoryBuffer.first));
      } else {
        final latestAt = territoryBuffer.first['created_at']?.toString() ?? '';
        final oldestAt = territoryBuffer.last['created_at']?.toString() ?? '';
        final key =
            'territory_${latestAt}_${oldestAt}_${territoryBuffer.length}';
        result.add(
          _PointDisplayItem.territoryGroup(
            key: key,
            items: List<Map<String, dynamic>>.from(territoryBuffer),
          ),
        );
      }
      territoryBuffer.clear();
    }

    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final eventType = (item['event_type'] ?? '').toString();
      if (_isTerritoryMaintainEvent(eventType)) {
        territoryBuffer.add(item);
        continue;
      }
      flushTerritoryBuffer();
      result.add(_PointDisplayItem.single(item));
    }
    flushTerritoryBuffer();
    return result;
  }

  Widget _buildDisplayCard(_PointDisplayItem item) {
    if (item.kind == _PointDisplayKind.territoryGroup) {
      return _buildTerritoryGroupCard(item);
    }
    return _buildHistoryCard(item.singleItem!);
  }

  Widget _buildTerritoryGroupCard(_PointDisplayItem group) {
    final items = group.groupedItems!;
    final totalPoints = items.fold<double>(
      0.0,
      (sum, item) => sum + _asDouble(item['points_delta']),
    );
    final isExpanded = _expandedTerritoryGroupKeys.contains(group.key);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedTerritoryGroupKeys.remove(group.key);
            } else {
              _expandedTerritoryGroupKeys.add(group.key);
            }
          });
        },
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.outlined_flag_rounded,
                    color: Colors.orangeAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    '영토 유지',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "+${totalPoints.toStringAsFixed(1)} P",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppColors.secondaryText,
            ),
            if (isExpanded) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: items
                      .map((item) {
                        final points = _asDouble(item['points_delta']);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '영토 유지',
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                "+${points.toStringAsFixed(1)} P",
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    final String eventType = (item['event_type'] ?? '').toString();
    final double pointsDelta = _asDouble(item['points_delta']);
    final String createdAtStr = (item['created_at'] ?? '').toString();
    final Color accentColor = _getEventTypeColor(eventType);

    DateTime? createdAt;
    if (createdAtStr.isNotEmpty) {
      createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
    }

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _getEventTypeIcon(eventType),
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getEventTypeText(eventType),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  createdAt != null
                      ? DateFormat('yyyy.MM.dd  HH:mm').format(createdAt)
                      : '-',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "${pointsDelta > 0 ? '+' : ''}${pointsDelta.toStringAsFixed(1)} P",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (_isRunPointEvent(eventType)) {
      return InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () =>
            _openRunReportFromPointItem(Map<String, dynamic>.from(item)),
        child: card,
      );
    }
    return card;
  }
}

class _SummaryIconCard extends StatelessWidget {
  const _SummaryIconCard({
    required this.icon,
    required this.accentColor,
    required this.value,
  });

  final IconData icon;
  final Color accentColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PointDisplayKind { single, territoryGroup }

class _PointDisplayItem {
  const _PointDisplayItem._({
    required this.kind,
    required this.key,
    this.singleItem,
    this.groupedItems,
  });

  factory _PointDisplayItem.single(Map<String, dynamic> item) {
    final key = item['created_at']?.toString() ?? UniqueKey().toString();
    return _PointDisplayItem._(
      kind: _PointDisplayKind.single,
      key: key,
      singleItem: item,
    );
  }

  factory _PointDisplayItem.territoryGroup({
    required String key,
    required List<Map<String, dynamic>> items,
  }) {
    return _PointDisplayItem._(
      kind: _PointDisplayKind.territoryGroup,
      key: key,
      groupedItems: items,
    );
  }

  final _PointDisplayKind kind;
  final String key;
  final Map<String, dynamic>? singleItem;
  final List<Map<String, dynamic>>? groupedItems;
}
