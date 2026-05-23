import 'supabase_api.dart';

class RunHistoryEntry {
  const RunHistoryEntry({
    required this.raw,
    required this.startedAt,
    required this.distanceMetres,
    required this.durationSeconds,
    required this.point,
    required this.avgPaceSecondsPerKm,
  });

  final Map<String, dynamic> raw;
  final DateTime? startedAt;
  final double distanceMetres;
  final int durationSeconds;
  final double point;
  final double avgPaceSecondsPerKm;

  factory RunHistoryEntry.fromMap(Map<String, dynamic> raw) {
    return RunHistoryEntry(
      raw: raw,
      startedAt: DateTime.tryParse(raw['started_at']?.toString() ?? ''),
      distanceMetres: _asDouble(raw['distance']),
      durationSeconds: _asInt(raw['duration']),
      point: _asDouble(raw['point']),
      avgPaceSecondsPerKm: _asDouble(raw['avg_pace']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class RunHistoryService {
  RunHistoryService._();

  static final RunHistoryService instance = RunHistoryService._();

  Future<List<RunHistoryEntry>> fetchRunHistory({int limit = 50}) async {
    final decoded = await SupabaseApi.getFunctionJson(
      'run-history',
      queryParameters: {'limit': limit},
    );

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => RunHistoryEntry.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'] ?? decoded['data'] ?? decoded['runs'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((item) => RunHistoryEntry.fromMap(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }
    }

    throw const ApiException('run-history returned an invalid response');
  }
}
