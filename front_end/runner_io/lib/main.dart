import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) .env 로드
  await dotenv.load(fileName: ".env");

  // 2) Supabase 초기화
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 3) 익명 로그인 세션 확보
  final supabase = Supabase.instance.client;

  // 이미 세션 있으면 재로그인 안 함
  if (supabase.auth.currentSession == null) {
    try {
      final res = await supabase.auth.signInAnonymously();

      if (res.session == null) {
        // 세션이 없으면 오류 처리 (로그만 찍어도 됨)
        debugPrint('Anonymous sign-in failed: session is null');
      } else {
        debugPrint('Anonymous sign-in success: ${res.session!.user.id}');
      }
    } catch (e, st) {
      debugPrint('Anonymous sign-in error: $e\n$st');
    }
  }

  // 4) 앱 실행
  runApp(const RunnerApp());
}
