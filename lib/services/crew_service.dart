import 'supabase_api.dart';

enum CrewSort {
  score,
  members,
  activity,
  newest;

  String get apiValue {
    switch (this) {
      case CrewSort.score:
        return 'score';
      case CrewSort.members:
        return 'members';
      case CrewSort.activity:
        return 'activity';
      case CrewSort.newest:
        return 'new';
    }
  }
}

class CrewSummary {
  const CrewSummary({
    required this.id,
    required this.name,
    this.description,
    this.region,
    this.colorHex,
    required this.memberCount,
    required this.seasonScore,
    required this.cumulativeAreaM2,
    required this.isJoined,
    required this.isDefaultContribution,
    this.displayRank,
  });

  final String id;
  final String name;
  final String? description;
  final String? region;
  final String? colorHex;
  final int memberCount;
  final double seasonScore;
  final double cumulativeAreaM2;
  final bool isJoined;
  final bool isDefaultContribution;
  final int? displayRank;

  factory CrewSummary.fromJson(Map<String, dynamic> json) {
    return CrewSummary(
      id: _asString(json['id']),
      name: _asString(json['name']),
      description: _asNullableString(json['description']),
      region: _asNullableString(json['region']),
      colorHex: _asNullableString(json['color_hex']),
      memberCount: _asInt(json['member_count']),
      seasonScore: _asDouble(json['season_score']),
      cumulativeAreaM2: _asDouble(json['cumulative_area_m2']),
      isJoined: json['is_joined'] == true,
      isDefaultContribution: json['is_default_contribution'] == true,
      displayRank: json.containsKey('display_rank')
          ? _asInt(json['display_rank'])
          : null,
    );
  }
}

class CrewSeason {
  const CrewSeason({
    required this.seasonType,
    required this.anchorDate,
    required this.from,
    required this.to,
  });

  final String seasonType;
  final String anchorDate;
  final String from;
  final String to;

  factory CrewSeason.fromJson(Map<String, dynamic> json) {
    return CrewSeason(
      seasonType: _asString(json['season_type']),
      anchorDate: _asString(json['anchor_date']),
      from: _asString(json['from']),
      to: _asString(json['to']),
    );
  }
}

class CrewMemberContribution {
  const CrewMemberContribution({
    required this.userId,
    this.nickName,
    this.colorHex,
    required this.contributionScore,
    required this.contributionAreaM2,
    required this.displayRank,
  });

  final String userId;
  final String? nickName;
  final String? colorHex;
  final double contributionScore;
  final double contributionAreaM2;
  final int displayRank;

  factory CrewMemberContribution.fromJson(Map<String, dynamic> json) {
    return CrewMemberContribution(
      userId: _asString(json['user_id']),
      nickName: _asNullableString(json['nick_name']),
      colorHex: _asNullableString(json['color_hex']),
      contributionScore: _asDouble(json['contribution_score']),
      contributionAreaM2: _asDouble(json['contribution_area_m2']),
      displayRank: _asInt(json['display_rank']),
    );
  }
}

class CrewDetail {
  const CrewDetail({
    required this.season,
    required this.crew,
    required this.canViewMembers,
    required this.members,
  });

  final CrewSeason season;
  final CrewSummary crew;
  final bool canViewMembers;
  final List<CrewMemberContribution> members;

  factory CrewDetail.fromJson(Map<String, dynamic> json) {
    return CrewDetail(
      season: CrewSeason.fromJson(_asMap(json['season'], 'season')),
      crew: CrewSummary.fromJson(_asMap(json['crew'], 'crew')),
      canViewMembers: json['can_view_members'] == true,
      members: _asList(json['members'])
          .whereType<Map>()
          .map(
            (item) => CrewMemberContribution.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class CrewRanking {
  const CrewRanking({required this.season, required this.crews});

  final CrewSeason season;
  final List<CrewSummary> crews;

  factory CrewRanking.fromJson(Map<String, dynamic> json) {
    return CrewRanking(
      season: CrewSeason.fromJson(_asMap(json['season'], 'season')),
      crews: _asList(json['crews'])
          .whereType<Map>()
          .map((item) => CrewSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }
}

class CrewMutationResult {
  const CrewMutationResult({
    required this.status,
    this.membershipId,
    this.crew,
    this.membership,
  });

  final String status;
  final String? membershipId;
  final CrewSummary? crew;
  final Map<String, dynamic>? membership;

  factory CrewMutationResult.fromJson(Map<String, dynamic> json) {
    final crew = json['crew'];
    final membership = json['membership'];
    return CrewMutationResult(
      status: _asString(json['status']),
      membershipId: _asNullableString(json['membership_id']),
      crew: crew is Map
          ? CrewSummary.fromJson(Map<String, dynamic>.from(crew))
          : null,
      membership: membership is Map
          ? Map<String, dynamic>.from(membership)
          : null,
    );
  }
}

class CrewService {
  CrewService._();

  static final CrewService instance = CrewService._();

  Future<List<CrewSummary>> searchCrews({
    String? query,
    String? region,
    CrewSort sort = CrewSort.score,
    int limit = 20,
  }) async {
    final decoded = await SupabaseApi.getFunctionJson(
      'social-crews',
      queryParameters: {
        'mode': 'search',
        'sort': sort.apiValue,
        'limit': limit,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (region != null && region.trim().isNotEmpty) 'region': region.trim(),
      },
    );
    return _parseCrewList(decoded);
  }

  Future<List<CrewSummary>> fetchMyCrews() async {
    final decoded = await SupabaseApi.getFunctionJson(
      'social-crews',
      queryParameters: {'mode': 'my'},
    );
    return _parseCrewList(decoded);
  }

  Future<CrewDetail> fetchCrewDetail(
    String crewId, {
    String seasonType = 'week',
    DateTime? anchorDate,
    int memberLimit = 50,
  }) async {
    final decoded = await SupabaseApi.getFunctionJson(
      'social-crews',
      queryParameters: {
        'mode': 'detail',
        'crew_id': crewId.trim(),
        'season_type': seasonType,
        'member_limit': memberLimit,
        if (anchorDate != null) 'anchor_date': _dateKey(anchorDate),
      },
    );
    return CrewDetail.fromJson(
      SupabaseApi.requireJsonMap(decoded, 'social-crews'),
    );
  }

  Future<CrewRanking> fetchCrewRanking({
    required String seasonType,
    DateTime? anchorDate,
    int limit = 100,
  }) async {
    final decoded = await SupabaseApi.getFunctionJson(
      'social-crews',
      queryParameters: {
        'mode': 'ranking',
        'season_type': seasonType,
        'limit': limit,
        if (anchorDate != null) 'anchor_date': _dateKey(anchorDate),
      },
    );
    return CrewRanking.fromJson(
      SupabaseApi.requireJsonMap(decoded, 'social-crews'),
    );
  }

  Future<CrewMutationResult> joinCrew(String crewId) {
    return _postCrewAction('join', crewId);
  }

  Future<CrewMutationResult> leaveCrew(String crewId) {
    return _postCrewAction('leave', crewId);
  }

  Future<CrewMutationResult> setDefaultCrew(String crewId) {
    return _postCrewAction('set_default', crewId);
  }

  Future<CrewMutationResult> _postCrewAction(
    String action,
    String crewId,
  ) async {
    final decoded = await SupabaseApi.postFunctionJson(
      'social-crews',
      body: {'action': action, 'crew_id': crewId.trim()},
    );
    return CrewMutationResult.fromJson(
      SupabaseApi.requireJsonMap(decoded, 'social-crews'),
    );
  }

  List<CrewSummary> _parseCrewList(dynamic decoded) {
    final json = SupabaseApi.requireJsonMap(decoded, 'social-crews');
    return _asList(json['crews'])
        .whereType<Map>()
        .map((item) => CrewSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}

String _asString(dynamic value) => value?.toString() ?? '';

String? _asNullableString(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<dynamic> _asList(dynamic value) {
  return value is List ? List<dynamic>.from(value) : const [];
}

Map<String, dynamic> _asMap(dynamic value, String fieldName) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw ApiException('social-crews returned an invalid $fieldName');
}

String _dateKey(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.toIso8601String().split('T').first;
}
