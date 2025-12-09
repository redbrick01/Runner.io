import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/run_result.dart';

class RunService {
  RunService._();

  static final RunService instance = RunService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Edge Function: run-create 호출
  /// 지금은 실패해도 UI 흐름을 막지 않도록 에러를 rethrow 하지 않는다.
  Future<void> saveRun(RunResult result) async {
    final request = result.toRunCreateRequest();

    try {
      final response = await _supabase.functions.invoke(
        'run-create',
        body: request.toJson(),
      );

      // Supabase FunctionsResponse 타입이 버전에 따라 조금 다를 수 있어서
      // 안전하게 data만 로그로 찍어둔다.
      log('run-create response data: ${response.data}');
    } catch (e, st) {
      // 당장은 실패해도 UI 흐름은 계속 가야 하니까 rethrow 하지 말고 로그만 남김
      log('run-create error (ignored for now): $e', stackTrace: st);
    }
  }
}
