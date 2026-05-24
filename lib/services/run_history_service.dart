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

  Future<List<RunHistoryEntry>> fetchRunHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final decoded = await SupabaseApi.getFunctionJson(
      'run-history',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    return _parseEntries(decoded);
  }

  Future<List<RunHistoryEntry>> fetchAllRunHistory({
    int pageSize = 100,
    int maxPages = 20,
  }) async {
    final entries = <RunHistoryEntry>[];
    var offset = 0;
    final effectivePageSize = pageSize.clamp(1, 100);

    for (var page = 0; page < maxPages; page++) {
      final decoded = await SupabaseApi.getFunctionJson(
        'run-history',
        queryParameters: {'limit': effectivePageSize, 'offset': offset},
      );
      final pageEntries = _parseEntries(decoded);
      entries.addAll(pageEntries);

      final paging = decoded is Map<String, dynamic> ? decoded['paging'] : null;
      final hasMore = paging is Map && paging['has_more'] == true;
      if (!hasMore || pageEntries.isEmpty) {
        break;
      }
      offset += pageEntries.length;
    }

    return entries;
  }

  List<RunHistoryEntry> _parseEntries(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map(
            (item) => RunHistoryEntry.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    }

    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'] ?? decoded['data'] ?? decoded['runs'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map(
              (item) =>
                  RunHistoryEntry.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      }
    }

    throw const ApiException('run-history returned an invalid response');
  }
}
