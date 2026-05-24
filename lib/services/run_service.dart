import 'supabase_api.dart';

class RunService {
  RunService._();

  static final RunService instance = RunService._();

  Future<JsonMap> createRun({
    required JsonMap payload,
  }) async {
    final decoded = await SupabaseApi.postFunctionJson(
      'create-run',
      body: payload,
    );
    return SupabaseApi.requireJsonMap(decoded, 'create-run');
  }
}
