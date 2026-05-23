import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/ranking_service.dart';
import 'point_history_page.dart';

enum _RankingRangeType { day, week, month, year, all }

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  List<dynamic> _rankingList = [];
  bool _isLoading = true;
  _RankingRangeType _rangeType = _RankingRangeType.day;
  DateTime _anchorDate = DateTime.now();

  dynamic get _selfItem {
    for (final item in _rankingList) {
      if (item['is_self'] == true) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fetchRankings();
  }

  Future<void> _fetchRankings() async {
    try {
      final rankings = await RankingService.instance.fetchRankings(
        rangeType: _rangeType.name,
        anchorDate: _rangeType == _RankingRangeType.all ? null : _anchorDate,
      );
      setState(() {
        _rankingList = rankings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("랭킹 리스트 로드 실패 에러: $e");
      setState(() => _isLoading = false);
    }
  }

  String _formatPoint(dynamic point) {
    if (point == null) return "0";
    double val = point.toDouble();
    if (val == val.toInt()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  Color _rankAccentColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.blueGrey.shade300;
    if (rank == 3) return Colors.brown.shade300;
    return AppColors.primary;
  }

  DateTime _startOfWeek(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    final diff = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: diff));
  }

  String _rangeLabel() {
    if (_rangeType == _RankingRangeType.all) return '전체 기간';
    final y = _anchorDate.year.toString();
    final m = _anchorDate.month.toString().padLeft(2, '0');
    final d = _anchorDate.day.toString().padLeft(2, '0');
    if (_rangeType == _RankingRangeType.day) return '$y.$m.$d';
    if (_rangeType == _RankingRangeType.week) {
      final start = _startOfWeek(_anchorDate);
      final end = start.add(const Duration(days: 6));
      final sm = start.month.toString().padLeft(2, '0');
      final sd = start.day.toString().padLeft(2, '0');
      final em = end.month.toString().padLeft(2, '0');
      final ed = end.day.toString().padLeft(2, '0');
      return '${start.year}.$sm.$sd ~ $em.$ed';
    }
    if (_rangeType == _RankingRangeType.month) return '$y.$m';
    return y;
  }

  void _onRangeTypeChanged(_RankingRangeType nextType) {
    if (_rangeType == nextType) return;
    final now = DateTime.now();
    setState(() {
      _rangeType = nextType;
      if (nextType == _RankingRangeType.week) {
        _anchorDate = _startOfWeek(now);
      } else if (nextType == _RankingRangeType.month) {
        _anchorDate = DateTime(now.year, now.month, 1);
      } else if (nextType == _RankingRangeType.year) {
        _anchorDate = DateTime(now.year, 1, 1);
      } else if (nextType == _RankingRangeType.day) {
        _anchorDate = DateTime(now.year, now.month, now.day);
      }
      _isLoading = true;
    });
    _fetchRankings();
  }

  Widget _buildRangeToggleBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _RangeTab(
            label: '일',
            selected: _rangeType == _RankingRangeType.day,
            onTap: () => _onRangeTypeChanged(_RankingRangeType.day),
          ),
          _RangeTab(
            label: '주',
            selected: _rangeType == _RankingRangeType.week,
            onTap: () => _onRangeTypeChanged(_RankingRangeType.week),
          ),
          _RangeTab(
            label: '월',
            selected: _rangeType == _RankingRangeType.month,
            onTap: () => _onRangeTypeChanged(_RankingRangeType.month),
          ),
          _RangeTab(
            label: '년',
            selected: _rangeType == _RankingRangeType.year,
            onTap: () => _onRangeTypeChanged(_RankingRangeType.year),
          ),
          _RangeTab(
            label: '전체',
            selected: _rangeType == _RankingRangeType.all,
            onTap: () => _onRangeTypeChanged(_RankingRangeType.all),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        _rangeLabel(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _rankingList.isNotEmpty;
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildRangeToggleBar(),
                const SizedBox(height: 10),
                _buildRangeNavigator(),
                if (hasData) ...[
                  const SizedBox(height: 12),
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      "랭킹 리스트",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._rankingList.map((item) {
                    final int rank =
                        item['display_rank'] ??
                        (_rankingList.indexOf(item) + 1);
                    final String nickname =
                        item['nick_name'] ?? item['nickname'] ?? "익명";
                    final dynamic points = item['total_points'] ?? 0;
                    final bool isSelf = item['is_self'] ?? false;
                    return _buildRankingItem(rank, nickname, points, isSelf);
                  }),
                ] else ...[
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      "데이터가 없습니다.",
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    final self = _selfItem;
    final selfRank = self?['display_rank'];
    final selfPoints = self?['total_points'] ?? 0;
    final selfNickname = self?['nick_name'] ?? self?['nickname'] ?? "게스트";
    final hasSelf = self != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasSelf ? "내 현재 순위" : "랭킹 스냅샷",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              selfRank != null ? "$selfRank위" : "TOP 랭킹",
              style: const TextStyle(
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              selfNickname,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  const Text(
                    "누적 포인트",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${_formatPoint(selfPoints)} P",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingItem(
    int rank,
    String nickname,
    dynamic points,
    bool isSelf,
  ) {
    final rankColor = _rankAccentColor(rank);

    return GestureDetector(
      onTap: isSelf
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PointHistoryPage(),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: isSelf
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  width: 1.6,
                )
              : null,
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
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: rank <= 3 ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                "$rank",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Text(
                    nickname,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelf ? FontWeight.w800 : FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (isSelf) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "나",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${_formatPoint(points)} P",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeTab extends StatelessWidget {
  const _RangeTab({
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
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
