import 'package:flutter/foundation.dart';

import 'profile_service.dart';

class UserProfileSnapshot {
  const UserProfileSnapshot({
    required this.rank,
    required this.area,
    required this.id,
    required this.nickName,
    required this.totalPoints,
    required this.colorHex,
    required this.createdAt,
    required this.userId,
    required this.heightCm,
    required this.weightKg,
    required this.rawResponse,
  });

  final int rank;
  final double area;
  final int? id;
  final String? nickName;
  final double totalPoints;
  final String? colorHex;
  final DateTime? createdAt;
  final String? userId;
  final double? heightCm;
  final double? weightKg;
  final Map<String, dynamic> rawResponse;

  UserProfileSnapshot copyWith({
    int? rank,
    double? area,
    int? id,
    String? nickName,
    double? totalPoints,
    String? colorHex,
    DateTime? createdAt,
    String? userId,
    double? heightCm,
    double? weightKg,
    Map<String, dynamic>? rawResponse,
  }) {
    return UserProfileSnapshot(
      rank: rank ?? this.rank,
      area: area ?? this.area,
      id: id ?? this.id,
      nickName: nickName ?? this.nickName,
      totalPoints: totalPoints ?? this.totalPoints,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }

  factory UserProfileSnapshot.fromResponseMap(Map<String, dynamic> responseMap) {
    final data = (responseMap['data'] as Map<String, dynamic>?) ?? responseMap;
    final profile = (data['profile'] as Map<String, dynamic>?) ??
        (data['self'] as Map<String, dynamic>?) ??
        (data['user'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final user = (data['user'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return UserProfileSnapshot(
      rank: _asInt(
        data['rank'] ??
            user['rank'] ??
            profile['rank'],
      ),
      area: _asDouble(
        data['area'] ??
            user['area'] ??
            profile['area'],
      ),
      id: profile['id'] is num ? (profile['id'] as num).toInt() : null,
      nickName: (profile['nick_name'] ?? profile['nickname'])?.toString(),
      totalPoints: _asDouble(
        profile['total_points'] ??
            profile['points'] ??
            user['total_points'],
      ),
      colorHex: profile['color_hex']?.toString(),
      createdAt: DateTime.tryParse(profile['created_at']?.toString() ?? ''),
      userId: (profile['user_id'] ?? user['user_id'] ?? user['id'])?.toString(),
      heightCm: _asNullableDouble(profile['height_cm']),
      weightKg: _asNullableDouble(profile['weight_kg']),
      rawResponse: responseMap,
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

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class UserProfileStore extends ChangeNotifier {
  UserProfileStore._();

  static final UserProfileStore instance = UserProfileStore._();

  UserProfileSnapshot? _current;
  bool _isFetching = false;

  UserProfileSnapshot? get current => _current;
  bool get hasData => _current != null;
  bool get isFetching => _isFetching;

  Future<UserProfileSnapshot?> fetch({bool force = false}) async {
    if (_isFetching) return _current;
    if (!force && _current != null) return _current;

    _isFetching = true;
    try {
      final decoded = await ProfileService.instance.fetchCurrentProfile();
      var snapshot = UserProfileSnapshot.fromResponseMap(decoded);
      final resolvedRank = await _fetchLeaderboardRank();
      if (resolvedRank != null && resolvedRank > 0) {
        snapshot = snapshot.copyWith(rank: resolvedRank);
      }

      _current = snapshot;
      notifyListeners();
      return _current;
    } catch (e) {
      debugPrint('유저 랭킹 정보 로드 실패: $e');
      return _current;
    } finally {
      _isFetching = false;
    }
  }

  void updateLocal({
    String? nickName,
    String? colorHex,
    double? heightCm,
    double? weightKg,
  }) {
    final current = _current;
    if (current == null) return;

    _current = current.copyWith(
      nickName: nickName ?? current.nickName,
      colorHex: colorHex ?? current.colorHex,
      heightCm: heightCm ?? current.heightCm,
      weightKg: weightKg ?? current.weightKg,
    );
    notifyListeners();
  }

  void clear() {
    _current = null;
    notifyListeners();
  }

  Future<int?> _fetchLeaderboardRank() async {
    try {
      return await ProfileService.instance.fetchLeaderboardRank();
    } catch (e) {
      debugPrint('리더보드 랭킹 정보 로드 실패: $e');
      return null;
    }
  }
}
