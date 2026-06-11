import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../app_colors.dart';
import '../design/app_design.dart';
import '../login/login_page.dart';
import '../services/achievement_service.dart';
import '../services/auth_service.dart';
import '../services/live_run_coaching_settings.dart';
import '../services/run_history_service.dart';
import '../services/user_profile_store.dart';
import 'achievement_page.dart';
import 'point_history_page.dart';
import 'profile_edit_page.dart';
import 'run_history_page.dart';
import 'statistics_page.dart';
import 'territory_detail_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  static const MethodChannel _liveActivityChannel = MethodChannel(
    'run_live_activity',
  );
  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _isTestingTts = false;
  bool _isAiPaceCoachEnabled = true;
  List<Achievement> _representativeBadges = const [];
  final FlutterTts _testTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAiCoachSetting();
  }

  Future<void> _loadAiCoachSetting() async {
    try {
      final enabled = await LiveRunCoachingSettings.instance.isEnabled();
      if (mounted) {
        setState(() => _isAiPaceCoachEnabled = enabled);
      }
    } catch (_) {}
  }

  Future<void> _setAiCoachEnabled(bool value) async {
    setState(() => _isAiPaceCoachEnabled = value);
    await LiveRunCoachingSettings.instance.setEnabled(value);
  }

  Future<void> _loadProfile() async {
    UserProfileSnapshot? snapshot;
    try {
      snapshot = await UserProfileStore.instance.fetch(force: true);
    } catch (_) {
      // Ignore and show cached/default values.
      snapshot = UserProfileStore.instance.current;
    }

    try {
      final entries = await RunHistoryService.instance.fetchAllRunHistory();
      final achievements = const AchievementService().buildAchievements(
        entries: entries,
        profile: snapshot,
      );
      _representativeBadges = achievements
          .where((item) => item.isAchieved)
          .take(3)
          .toList(growable: false);
    } catch (_) {
      _representativeBadges = const [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openProfileEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const ProfileEditPage()),
    );
    if (updated == true && mounted) {
      await _loadProfile();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await AuthService.instance.signOut();
      UserProfileStore.instance.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _testSplitTts() async {
    if (_isTestingTts) return;
    setState(() => _isTestingTts = true);
    try {
      if (Platform.isIOS) {
        await _testTts.setSharedInstance(true);
        await _testTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          const [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } else if (Platform.isAndroid) {
        await _testTts.setAudioAttributesForNavigation();
      }
      await _testTts.setLanguage('ko-KR');
      await _testTts.setSpeechRate(0.48);
      await _testTts.setPitch(1.0);
      try {
        await _liveActivityChannel.invokeMethod<void>('playSplitChime');
      } catch (_) {
        await SystemSound.play(SystemSoundType.alert);
      }
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await _testTts.stop();
      await _testTts.speak('테스트 안내입니다. 1킬로미터, 구간 페이스 5분 20초');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('TTS 테스트 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _isTestingTts = false);
      }
    }
  }

  @override
  void dispose() {
    _testTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = UserProfileStore.instance.current;
    final nickname = snapshot?.nickName?.trim().isNotEmpty == true
        ? snapshot!.nickName!.trim()
        : '게스트';
    final friendCode = snapshot?.friendCode?.trim();
    final colorHex = snapshot?.colorHex;
    final avatarColor = _resolveProfileColor(colorHex);
    final points = snapshot?.totalPoints ?? 0.0;
    final areaKm2 = (snapshot?.area ?? 0.0) / 1000000;
    final rank = snapshot?.rank ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '마이페이지',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: AppSpacing.page,
                children: [
                  AppSurface(
                    padding: const EdgeInsets.all(18),
                    radius: 22,
                    shadow: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: avatarColor,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: avatarColor.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      nickname,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (friendCode != null &&
                                      friendCode.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        friendCode,
                                        style: AppTextStyles.label.copyWith(
                                          color: AppColors.disabledText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '랭킹 ${rank > 0 ? '$rank위' : '-'}',
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _MyMetric(
                                label: '포인트',
                                value: '${points.toStringAsFixed(1)} P',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MyMetric(
                                label: '점령 면적',
                                value: '${areaKm2.toStringAsFixed(2)} km²',
                              ),
                            ),
                          ],
                        ),
                        if (_representativeBadges.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _RepresentativeBadges(badges: _representativeBadges),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MyMenuTile(
                    icon: Icons.manage_accounts_outlined,
                    title: '개인정보 수정',
                    subtitle: '닉네임, 비밀번호, 키/몸무게 수정',
                    onTap: _openProfileEdit,
                  ),
                  _MyMenuTile(
                    icon: Icons.bar_chart_rounded,
                    title: '러닝 통계',
                    subtitle: '주간/월간 요약과 개인 최고 기록',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatisticsPage(),
                        ),
                      );
                    },
                  ),
                  _MyMenuTile(
                    icon: Icons.emoji_events_rounded,
                    title: '배지/업적',
                    subtitle: '달성한 배지와 다음 목표 보기',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementPage(),
                        ),
                      );
                    },
                  ),
                  _MyMenuTile(
                    icon: Icons.assignment_rounded,
                    title: '러닝 리포트',
                    subtitle: '저장된 러닝 기록과 상세 결과 보기',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RunHistoryPage(),
                        ),
                      );
                    },
                  ),
                  _MyMenuTile(
                    icon: Icons.landscape_rounded,
                    title: '점령면적 상세',
                    subtitle: '면적 변화, 지도, 기여 러닝 보기',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TerritoryDetailPage(),
                        ),
                      );
                    },
                  ),
                  _MyMenuTile(
                    icon: Icons.history_rounded,
                    title: '포인트 내역',
                    subtitle: '포인트 획득/사용 기록 보기',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PointHistoryPage(),
                        ),
                      );
                    },
                  ),
                  _MyMenuTile(
                    icon: Icons.record_voice_over_rounded,
                    title: _isTestingTts ? 'TTS 테스트 재생 중...' : 'TTS 테스트 (임시)',
                    subtitle: '띵 효과음 후 음성 안내를 테스트합니다',
                    onTap: _isTestingTts ? () {} : _testSplitTts,
                  ),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    radius: 16,
                    child: SwitchListTile.adaptive(
                      secondary: const Icon(
                        Icons.psychology_alt_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'AI 페이스 코치',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: const Text('1km 페이스 알림 뒤에 짧은 코칭을 들려줍니다'),
                      value: _isAiPaceCoachEnabled,
                      onChanged: _setAiCoachEnabled,
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    radius: 16,
                    child: TextButton.icon(
                      onPressed: _isLoggingOut ? null : _logout,
                      icon: _isLoggingOut
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.logout_rounded,
                              color: Colors.redAccent,
                            ),
                      label: const Text(
                        '로그아웃',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

Color _resolveProfileColor(String? colorHex) {
  if (colorHex == null || colorHex.trim().isEmpty) {
    return AppColors.primary;
  }
  final normalized = colorHex.trim();
  final hex = normalized.startsWith('#') ? normalized.substring(1) : normalized;
  if (hex.length != 6) {
    return AppColors.primary;
  }
  final value = int.tryParse(hex, radix: 16);
  if (value == null) {
    return AppColors.primary;
  }
  return Color(0xFF000000 | value);
}

class _MyMetric extends StatelessWidget {
  const _MyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppColors.surfaceSoft,
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepresentativeBadges extends StatelessWidget {
  const _RepresentativeBadges({required this.badges});

  final List<Achievement> badges;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '대표 배지',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: badges
              .map((badge) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: badge.title,
                    child: AppSurface(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(3),
                      color: AppColors.primarySoft,
                      radius: 13,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/badges/generated/icons/${badge.iconType}.png',
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.primary,
                              size: 22,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _MyMenuTile extends StatelessWidget {
  const _MyMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AppSurface(
          padding: const EdgeInsets.all(14),
          radius: 16,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
