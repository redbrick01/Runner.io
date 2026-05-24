import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

typedef NativeRunActionHandler =
    Future<void> Function(Map<String, dynamic> payload);

class RunNativeAdapter {
  RunNativeAdapter({
    MethodChannel channel = const MethodChannel('run_live_activity'),
    FlutterTts? splitTts,
  }) : _channel = channel,
       _splitTts = splitTts ?? FlutterTts();

  final MethodChannel _channel;
  final FlutterTts _splitTts;
  bool _isSplitTtsConfigured = false;

  void setActionHandler(NativeRunActionHandler? handler) {
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onLiveActivityAction') return;
      await handler(Map<String, dynamic>.from(call.arguments as Map));
    });
  }

  Future<T?> invoke<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _splitTts.stop();
  }

  Future<void> configureSplitTts() async {
    if (_isSplitTtsConfigured) return;

    if (Platform.isIOS) {
      await _splitTts.setSharedInstance(true);
      await _splitTts.setIosAudioCategory(
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
      await _splitTts.setAudioAttributesForNavigation();
    }

    await _splitTts.setLanguage('ko-KR');
    await _splitTts.setSpeechRate(0.48);
    await _splitTts.setPitch(1.0);
    await _splitTts.awaitSpeakCompletion(false);
    _isSplitTtsConfigured = true;
  }

  Future<void> playSplitChime() async {
    try {
      await invoke<void>('playSplitChime');
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (e) {
        debugPrint('Split chime play failed: $e');
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  Future<void> playRunStartEffect() async {
    try {
      await invoke<void>('playSplitChime');
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  Future<void> speakSplit(String speech) async {
    await configureSplitTts();
    await playSplitChime();
    await _splitTts.stop();
    await _splitTts.speak(speech);
  }
}
