import 'supabase_api.dart';

class RunAiReport {
  const RunAiReport({
    required this.runId,
    required this.summary,
    required this.improvements,
    required this.nextGoal,
    required this.coachingMessage,
    required this.comparison,
    required this.status,
    required this.model,
    this.errorMessage,
    this.createdAt,
  });

  final int runId;
  final String summary;
  final List<String> improvements;
  final Map<String, dynamic> nextGoal;
  final String coachingMessage;
  final Map<String, dynamic> comparison;
  final String status;
  final String model;
  final String? errorMessage;
  final DateTime? createdAt;

  bool get isCompleted => status == 'completed';
  bool get isInsufficientData => status == 'insufficient_data';
  bool get isFailed => status == 'failed';

  String get nextGoalLabel {
    final label = nextGoal['label'];
    if (label is String && label.trim().isNotEmpty) {
      return label;
    }
    return '다음 러닝에서 같은 거리를 일정한 페이스로 완주';
  }

  int get similarRunCount {
    final count = comparison['similar_run_count'];
    if (count is num) return count.toInt();
    return int.tryParse(count?.toString() ?? '') ?? 0;
  }

  factory RunAiReport.fromMap(Map<String, dynamic> raw) {
    final improvementsRaw = raw['improvements'];
    final nextGoalRaw = raw['next_goal'];
    final comparisonRaw = raw['comparison'];

    return RunAiReport(
      runId: _asInt(raw['run_id']),
      summary: raw['summary']?.toString() ?? '',
      improvements: improvementsRaw is List
          ? improvementsRaw.map((item) => item.toString()).toList()
          : const [],
      nextGoal: nextGoalRaw is Map
          ? Map<String, dynamic>.from(nextGoalRaw)
          : const {},
      coachingMessage: raw['coaching_message']?.toString() ?? '',
      comparison: comparisonRaw is Map
          ? Map<String, dynamic>.from(comparisonRaw)
          : const {},
      status: raw['status']?.toString() ?? 'pending',
      model: raw['model']?.toString() ?? 'gpt-5.4-mini',
      errorMessage: raw['error_message']?.toString(),
      createdAt: DateTime.tryParse(raw['created_at']?.toString() ?? ''),
    );
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class RunAiReportService {
  RunAiReportService._();

  static final RunAiReportService instance = RunAiReportService._();

  Future<RunAiReport?> fetchRunReport(int runId) async {
    final decoded = await SupabaseApi.getFunctionJson(
      'run-ai-report',
      queryParameters: {'run_id': runId},
    );
    return _parseReportResponse(decoded);
  }

  Future<RunAiReport?> fetchLatestReport() async {
    final decoded = await SupabaseApi.getFunctionJson(
      'run-ai-report',
      queryParameters: {'latest': true},
    );
    return _parseReportResponse(decoded);
  }

  Future<RunAiReport?> generateRunReport(int runId) async {
    final decoded = await SupabaseApi.postFunctionJson(
      'generate-run-ai-report',
      body: {'run_id': runId},
    );
    return _parseReportResponse(decoded);
  }

  Future<dynamic> backfillRunEmbeddings({int limit = 20}) {
    return SupabaseApi.postFunctionJson(
      'backfill-run-embeddings',
      body: const {},
      queryParameters: {'limit': limit},
    );
  }

  RunAiReport? _parseReportResponse(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final report = decoded['report'];
      if (report == null) return null;
      if (report is Map) {
        return RunAiReport.fromMap(Map<String, dynamic>.from(report));
      }
    }
    throw const ApiException('run-ai-report returned an invalid response');
  }
}
