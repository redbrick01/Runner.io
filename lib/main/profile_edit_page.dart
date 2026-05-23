import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../app_colors.dart';
import '../login/login_page.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/user_profile_store.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  Color _pickerColor = AppColors.primary;
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final cached = UserProfileStore.instance.current;
    if (cached != null) {
      if (cached.colorHex != null && cached.colorHex!.isNotEmpty) {
        _pickerColor = Color(
          int.parse(cached.colorHex!.replaceFirst('#', '0xFF')),
        );
      }
      if (cached.heightCm != null && cached.heightCm! > 0) {
        _heightController.text = _formatMetricInput(cached.heightCm!);
      }
      if (cached.weightKg != null && cached.weightKg! > 0) {
        _weightController.text = _formatMetricInput(cached.weightKg!);
      }
    }

    try {
      final snapshot = await UserProfileStore.instance.fetch(force: true);
      if (snapshot != null) {
        if (snapshot.colorHex != null && snapshot.colorHex!.isNotEmpty) {
          _pickerColor = Color(
            int.parse(snapshot.colorHex!.replaceFirst('#', '0xFF')),
          );
        }
        if (snapshot.heightCm != null && snapshot.heightCm! > 0) {
          _heightController.text = _formatMetricInput(snapshot.heightCm!);
        }
        if (snapshot.weightKg != null && snapshot.weightKg! > 0) {
          _weightController.text = _formatMetricInput(snapshot.weightKg!);
        }
      }
    } catch (e) {
      debugPrint("현재 프로필 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await ProfileService.instance.updateProfile(
        nickName: _nicknameController.text,
        password: _passwordController.text,
        colorHex: _currentColorHex,
        heightCm: _parseMetricInput(_heightController.text),
        weightKg: _parseMetricInput(_weightController.text),
      );

      UserProfileStore.instance.updateLocal(
        nickName: _nicknameController.text.isEmpty
            ? null
            : _nicknameController.text,
        colorHex: _currentColorHex,
        heightCm: _parseMetricInput(_heightController.text),
        weightKg: _parseMetricInput(_weightController.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프로필이 성공적으로 업데이트되었습니다.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("프로필 업데이트 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('업데이트 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("로그아웃"),
        content: const Text("정말로 로그아웃 하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "로그아웃",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.instance.signOut();
      UserProfileStore.instance.clear();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _confirmAndUpdateProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("개인정보 수정"),
        content: const Text("입력한 내용으로 개인정보를 수정하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("수정", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateProfile();
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('색상 선택'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _pickerColor,
            onColorChanged: (color) => setState(() => _pickerColor = color),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String get _currentColorHex {
    return '#${_pickerColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  String _formatMetricInput(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  double? _parseMetricInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  String? _validateHeight(String? value) {
    final parsed = _parseMetricInput(value ?? '');
    if (parsed == null) {
      return null;
    }
    if (parsed <= 0 || parsed >= 300) {
      return "키는 1~299cm 범위로 입력해주세요.";
    }
    return null;
  }

  String? _validateWeight(String? value) {
    final parsed = _parseMetricInput(value ?? '');
    if (parsed == null) {
      return null;
    }
    if (parsed <= 0 || parsed >= 500) {
      return "몸무게는 1~499kg 범위로 입력해주세요.";
    }
    return null;
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9AA3B2),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: const Color(0xFF7B8794)),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
    );
  }

  Widget _buildProfilePreviewCard() {
    final snapshot = UserProfileStore.instance.current;
    final cachedNickname = UserProfileStore.instance.current?.nickName?.trim();
    final inputNickname = _nicknameController.text.trim();
    final nickname = inputNickname.isNotEmpty
        ? inputNickname
        : ((cachedNickname != null && cachedNickname.isNotEmpty)
              ? cachedNickname
              : '닉네임 미설정');
    final rankText = snapshot != null ? '${snapshot.rank}위' : '-';
    final pointsText = snapshot != null
        ? '${snapshot.totalPoints.toStringAsFixed(1)} P'
        : '-';

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _showColorPicker,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pickerColor,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: _pickerColor.withValues(alpha: 0.26),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '랭킹 $rankText  /  포인트 $pointsText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfilePreviewCard(),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: "프로필 정보",
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nicknameController,
                            decoration: _inputDecoration(
                              hintText: "변경할 닉네임을 입력하세요",
                              prefixIcon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: _inputDecoration(
                              hintText: "새 비밀번호를 입력하세요",
                              prefixIcon: Icons.lock_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _validateHeight,
                            decoration: _inputDecoration(
                              hintText: "키(cm)를 입력하세요",
                              prefixIcon: Icons.height_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _validateWeight,
                            decoration: _inputDecoration(
                              hintText: "몸무게(kg)를 입력하세요",
                              prefixIcon: Icons.monitor_weight_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : _confirmAndUpdateProfile,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text(
                                "개인정보 수정",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          "로그아웃",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
