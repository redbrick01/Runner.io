import 'supabase_api.dart';

enum FriendResponse {
  accepted,
  rejected;

  String get apiValue => name;
}

class FriendCodeResponse {
  const FriendCodeResponse({required this.friendCode});

  final String friendCode;

  factory FriendCodeResponse.fromJson(Map<String, dynamic> json) {
    return FriendCodeResponse(friendCode: _asString(json['friend_code']));
  }
}

class FriendProfile {
  const FriendProfile({
    required this.userId,
    this.nickName,
    this.colorHex,
    this.friendCode,
  });

  final String userId;
  final String? nickName;
  final String? colorHex;
  final String? friendCode;

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      userId: _asString(json['user_id']),
      nickName: _asNullableString(json['nick_name']),
      colorHex: _asNullableString(json['color_hex']),
      friendCode: _asNullableString(json['friend_code']),
    );
  }
}

class IncomingFriendRequest {
  const IncomingFriendRequest({
    required this.friendshipId,
    required this.createdAt,
    required this.requester,
  });

  final String friendshipId;
  final DateTime? createdAt;
  final FriendProfile requester;

  factory IncomingFriendRequest.fromJson(Map<String, dynamic> json) {
    return IncomingFriendRequest(
      friendshipId: _asString(json['friendship_id']),
      createdAt: DateTime.tryParse(_asString(json['created_at'])),
      requester: FriendProfile.fromJson(_asMap(json['requester'], 'requester')),
    );
  }
}

class FriendRequestResult {
  const FriendRequestResult({
    required this.friendshipId,
    required this.status,
    this.addressee,
  });

  final String friendshipId;
  final String status;
  final FriendProfile? addressee;

  factory FriendRequestResult.fromJson(Map<String, dynamic> json) {
    final addressee = json['addressee'];
    return FriendRequestResult(
      friendshipId: _asString(json['friendship_id']),
      status: _asString(json['status']),
      addressee: addressee is Map
          ? FriendProfile.fromJson(Map<String, dynamic>.from(addressee))
          : null,
    );
  }
}

class FriendResponseResult {
  const FriendResponseResult({
    required this.friendshipId,
    required this.status,
    this.respondedAt,
  });

  final String friendshipId;
  final String status;
  final DateTime? respondedAt;

  factory FriendResponseResult.fromJson(Map<String, dynamic> json) {
    return FriendResponseResult(
      friendshipId: _asString(json['friendship_id']),
      status: _asString(json['status']),
      respondedAt: DateTime.tryParse(_asString(json['responded_at'])),
    );
  }
}

class FriendRankingItem {
  const FriendRankingItem({
    required this.userId,
    this.nickName,
    this.colorHex,
    required this.totalPoints,
    required this.displayRank,
    required this.isSelf,
  });

  final String userId;
  final String? nickName;
  final String? colorHex;
  final double totalPoints;
  final int displayRank;
  final bool isSelf;

  factory FriendRankingItem.fromJson(Map<String, dynamic> json) {
    return FriendRankingItem(
      userId: _asString(json['user_id']),
      nickName: _asNullableString(json['nick_name']),
      colorHex: _asNullableString(json['color_hex']),
      totalPoints: _asDouble(json['total_points']),
      displayRank: _asInt(json['display_rank']),
      isSelf: json['is_self'] == true,
    );
  }
}

class SocialRange {
  const SocialRange({
    required this.rangeType,
    required this.anchorDate,
    required this.from,
    required this.to,
  });

  final String rangeType;
  final String anchorDate;
  final String from;
  final String to;

  factory SocialRange.fromJson(Map<String, dynamic> json) {
    return SocialRange(
      rangeType: _asString(json['range_type']),
      anchorDate: _asString(json['anchor_date']),
      from: _asString(json['from']),
      to: _asString(json['to']),
    );
  }
}

class FriendRanking {
  const FriendRanking({required this.range, required this.results});

  final SocialRange range;
  final List<FriendRankingItem> results;

  factory FriendRanking.fromJson(Map<String, dynamic> json) {
    return FriendRanking(
      range: SocialRange.fromJson(_asMap(json['range'], 'range')),
      results: _asList(json['results'])
          .whereType<Map>()
          .map(
            (item) =>
                FriendRankingItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

class SocialService {
  SocialService._();

  static final SocialService instance = SocialService._();

  Future<String> fetchMyFriendCode() async {
    final decoded = await SupabaseApi.getFunctionJson(
      'social-friends',
      queryParameters: {'mode': 'me'},
    );
    return FriendCodeResponse.fromJson(
      SupabaseApi.requireJsonMap(decoded, 'social-friends'),
    ).friendCode;
  }

  Future<FriendProfile> lookupFriendCode(String code) async {
    final decoded = await SupabaseApi.getFunctionJson(
      'social-friends',
      queryParameters: {
        'mode': 'lookup',
        'friend_code': code.trim().toUpperCase(),
      },
    );
    final json = SupabaseApi.requireJsonMap(decoded, 'social-friends');
    return FriendProfile.fromJson(_asMap(json['profile'], 'profile'));
  }

  Future<FriendRequestResult> sendFriendRequest(String code) async {
    final decoded = await SupabaseApi.postFunctionJson(
      'social-friends',
      body: {'action': 'request', 'friend_code': code.trim().toUpperCase()},
    );
    return FriendRequestResult.fromJson(
      SupabaseApi.requireJsonMap(decoded, 'social-friends'),
    );
  }

  Future<List<IncomingFriendRequest>> fetchIncomingRequests() async {
    final decoded = await SupabaseApi.getFunctionJson(
      'social-friends',
      queryParameters: {'mode': 'requests'},
    );
    final json = SupabaseApi.requireJsonMap(decoded, 'social-friends');
    return _asList(json['requests'])
        .whereType<Map>()
        .map(
          (item) =>
              IncomingFriendRequest.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<FriendResponseResult> respondToFriendRequest(
    String friendshipId,
    FriendResponse response,
  ) async {
    final decoded = await SupabaseApi.postFunctionJson(
      'social-friends',
      body: {
        'action': 'respond',
        'friendship_id': friendshipId.trim(),
        'status': response.apiValue,
      },
    );
    return FriendResponseResult.fromJson(
      SupabaseApi.requireJsonMap(decoded, 'social-friends'),
    );
  }

  Future<List<FriendProfile>> fetchFriends() async {
    final decoded = await SupabaseApi.getFunctionJson(
      'social-friends',
      queryParameters: {'mode': 'list'},
    );
    final json = SupabaseApi.requireJsonMap(decoded, 'social-friends');
    return _asList(json['friends'])
        .whereType<Map>()
        .map((item) => FriendProfile.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<FriendRanking> fetchFriendRanking({
    required String rangeType,
    DateTime? anchorDate,
  }) async {
    final decoded = await SupabaseApi.getFunctionJson(
      'social-friends',
      queryParameters: {
        'mode': 'ranking',
        'range_type': rangeType,
        if (anchorDate != null) 'anchor_date': _dateKey(anchorDate),
      },
    );
    return FriendRanking.fromJson(
      SupabaseApi.requireJsonMap(decoded, 'social-friends'),
    );
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
  throw ApiException('social-friends returned an invalid $fieldName');
}

String _dateKey(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.toIso8601String().split('T').first;
}
