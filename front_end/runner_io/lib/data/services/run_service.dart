import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/run_result.dart';

class RunService {
  RunService._();

  static final RunService instance = RunService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Edge Function: run-create 호출
  Future<void> saveRun(RunResult result) async {
    final request = result.toRunCreateRequest();

    try {
      final response = await _supabase.functions.invoke(
        'run-create',
        body: request.toJson(),
      );

      log('run-create success: ${response.data}');
    } catch (e, st) {
      log('run-create error: $e', stackTrace: st);
      rethrow;
    }
  }
}
