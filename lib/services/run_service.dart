import 'supabase_api.dart';

class RunService {
  RunService._();

  static final RunService instance = RunService._();

  Future<dynamic> createRun({
    required Map<String, dynamic> payload,
  }) {
    return SupabaseApi.postFunctionJson('create-run', body: payload);
  }
}
