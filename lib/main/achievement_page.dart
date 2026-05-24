import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/achievement_service.dart';
import '../services/run_history_service.dart';
import '../services/user_profile_store.dart';

class AchievementPage extends StatefulWidget {
  const AchievementPage({
    super.key,
    this.loadEntries,
    this.loadProfile,
    this.service = const AchievementService(),
  });

  final Future<List<RunHistoryEntry>> Function()? loadEntries;
  final Future<UserProfileSnapshot?> Function()? loadProfile;
  final AchievementService service;

  @override
  State<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends State<AchievementPage> {
  AchievementCategory? _selectedCategory;
  List<Achievement> _achievements = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loader =
          widget.loadEntries ??
          () => RunHistoryService.instance.fetchAllRunHistory();
      final profileLoader =
          widget.loadProfile ??
          () => UserProfileStore.instance.fetch(force: true);
      final results = await Future.wait<dynamic>([loader(), profileLoader()]);
      final entries = results[0] as List<RunHistoryEntry>;
      final profile = results[1] as UserProfileSnapshot?;
      final achievements = widget.service.buildAchievements(
        entries: entries,
        profile: profile,
      );
      if (!mounted) return;
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _achievements = widget.service.buildAchievements(entries: const []);
        _errorMessage = '배지를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == null
        ? _achievements
        : _achievements
              .where((item) => item.category == _selectedCategory)
              .toList(growable: false);
    final achievedCount = _achievements.where((item) => item.isAchieved).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '배지',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAchievements,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_errorMessage != null) ...[
                    _NoticeCard(message: _errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  _SummaryCard(
                    achievedCount: achievedCount,
                    totalCount: _achievements.length,
                  ),
                  const SizedBox(height: 12),
                  _CategoryFilter(
                    selected: _selectedCategory,
                    onChanged: (category) {
                      setState(() => _selectedCategory = category);
                    },
                  ),
                  const SizedBox(height: 12),
                  ...filtered.map(
                    (achievement) => _AchievementTile(
                      achievement: achievement,
                      onTap: () => _showAchievementDetail(achievement),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showAchievementDetail(Achievement achievement) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BadgeIcon(achievement: achievement, size: 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            achievement.title,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _categoryLabel(achievement.category),
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  achievement.description,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  achievement.conditionText,
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 14),
                _ProgressBar(achievement: achievement),
                const SizedBox(height: 12),
                Text(
                  achievement.isAchieved
                      ? '달성 완료${_formatDateSuffix(achievement.achievedAt)}'
                      : '현재 ${achievement.displayValue ?? '-'}',
                  style: TextStyle(
                    color: achievement.isAchieved
                        ? AppColors.primary
                        : AppColors.secondaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.achievedCount, required this.totalCount});

  final int achievedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount == 0 ? 0.0 : achievedCount / totalCount;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '업적 진행',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$achievedCount / $totalCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.selected, required this.onChanged});

  final AchievementCategory? selected;
  final ValueChanged<AchievementCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <AchievementCategory?>[
      null,
      AchievementCategory.start,
      AchievementCategory.distance,
      AchievementCategory.streak,
      AchievementCategory.growth,
      AchievementCategory.territory,
      AchievementCategory.habit,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .map((category) {
              final isSelected = selected == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    category == null ? '전체' : _categoryLabel(category),
                  ),
                  selected: isSelected,
                  onSelected: (_) => onChanged(category),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.secondaryText,
                    fontWeight: FontWeight.w800,
                  ),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.onTap});

  final Achievement achievement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = achievement.isAchieved ? 1.0 : 0.46;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: achievement.isAchieved
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: opacity,
                child: _BadgeIcon(achievement: achievement, size: 54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          achievement.isAchieved
                              ? Icons.check_circle_rounded
                              : Icons.lock_rounded,
                          color: achievement.isAchieved
                              ? AppColors.primary
                              : AppColors.secondaryText,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.conditionText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProgressBar(achievement: achievement),
                    const SizedBox(height: 6),
                    Text(
                      achievement.displayValue ?? '-',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.achievement, required this.size});

  final Achievement achievement;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/badges/generated/icons/${achievement.iconType}.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(size * 0.22),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.primary,
              size: size * 0.5,
            ),
          );
        },
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: achievement.progressRatio,
        minHeight: 7,
        backgroundColor: AppColors.background,
        valueColor: AlwaysStoppedAnimation<Color>(
          achievement.isAchieved ? AppColors.primary : AppColors.secondaryText,
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.secondaryText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _categoryLabel(AchievementCategory category) {
  return switch (category) {
    AchievementCategory.start => '시작',
    AchievementCategory.distance => '거리',
    AchievementCategory.streak => '연속',
    AchievementCategory.growth => '성장',
    AchievementCategory.territory => '영토',
    AchievementCategory.habit => '습관',
  };
}

String _formatDateSuffix(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return ' · ${local.year}.$month.$day';
}
