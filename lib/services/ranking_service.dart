import 'supabase_api.dart';

class RankingService {
  RankingService._();

  static final RankingService instance = RankingService._();

  Future<List<dynamic>> fetchRankings({
    String? rangeType,
    DateTime? anchorDate,
  }) async {
    final currentUser = SupabaseApi.currentUser;
    final mode = currentUser != null ? 'context' : 'top';
    final queryParameters = <String, dynamic>{
      'mode': mode,
      if (currentUser != null) 'user_id': currentUser.id,
    };
    if (rangeType != null && rangeType.isNotEmpty) {
      queryParameters['range_type'] = rangeType;
    }
    if (anchorDate != null) {
      final day = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
      queryParameters['anchor_date'] = day.toIso8601String().split('T').first;
    }
    final decoded = await SupabaseApi.getFunctionJson(
      'profile-leaderboard',
      queryParameters: queryParameters,
    );
    final parsed = _parseRankings(decoded);

    // context 모드에서 비어 있으면 top 모드로 한 번 더 조회해
    // "데이터 없음"이 과도하게 노출되는 상황을 줄인다.
    if (parsed.isNotEmpty || mode != 'context') {
      return parsed;
    }

    final topDecoded = await SupabaseApi.getFunctionJson(
      'profile-leaderboard',
      queryParameters: {
        ...queryParameters,
        'mode': 'top',
      },
    );
    return _parseRankings(topDecoded);
  }

  List<dynamic> _parseRankings(dynamic decoded) {

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('profile-leaderboard returned an invalid response');
    }

    final combinedList = <dynamic>[];
    if (decoded['mode'] == 'top') {
      final results = List<dynamic>.from(decoded['results'] as List? ?? const []);
      for (var i = 0; i < results.length; i++) {
        final item = Map<String, dynamic>.from(results[i] as Map);
        item['display_rank'] = i + 1;
        combinedList.add(item);
      }
      return combinedList;
    }

    if (decoded['mode'] == 'context') {
      final selfRank = decoded['user']?['rank'] is num
          ? (decoded['user']['rank'] as num).toInt()
          : int.tryParse(decoded['user']?['rank']?.toString() ?? '') ?? 0;
      final above = List<dynamic>.from(decoded['above'] as List? ?? const []);
      final self = decoded['self'];
      final below = List<dynamic>.from(decoded['below'] as List? ?? const []);

      for (var i = 0; i < above.length; i++) {
        final item = Map<String, dynamic>.from(above[i] as Map);
        item['display_rank'] = selfRank - (above.length - i);
        combinedList.add(item);
      }

      if (self is Map) {
        final item = Map<String, dynamic>.from(self);
        item['display_rank'] = selfRank;
        item['is_self'] = true;
        combinedList.add(item);
      }

      for (var i = 0; i < below.length; i++) {
        final item = Map<String, dynamic>.from(below[i] as Map);
        item['display_rank'] = selfRank + i + 1;
        combinedList.add(item);
      }
    }

    return combinedList;
  }
}
