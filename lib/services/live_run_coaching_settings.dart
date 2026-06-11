import 'package:shared_preferences/shared_preferences.dart';

class LiveRunCoachingSettings {
  LiveRunCoachingSettings._();

  static final LiveRunCoachingSettings instance = LiveRunCoachingSettings._();
  static const _enabledKey = 'live_run_ai_coach_enabled';

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
  }
}
