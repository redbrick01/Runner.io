import 'supabase_api.dart';

class PointHistoryService {
  PointHistoryService._();

  static final PointHistoryService instance = PointHistoryService._();

  Future<List<dynamic>> fetchPointHistory({
    int limit = 300,
    int offset = 0,
    String? rangeType,
    String? anchorDate,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (rangeType != null && rangeType.isNotEmpty) {
      query['range_type'] = rangeType;
    }
    if (anchorDate != null && anchorDate.isNotEmpty) {
      query['anchor_date'] = anchorDate;
    }

    final decoded = await SupabaseApi.getFunctionJson(
      'point-history',
      queryParameters: query,
    );

    if (decoded is List) {
      return List<dynamic>.from(decoded);
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('point-history returned an invalid response');
    }

    final payload = decoded['items'] ?? decoded['results'] ?? decoded['data'];
    if (payload is List) {
      return List<dynamic>.from(payload);
    }
    return const [];
  }
}
