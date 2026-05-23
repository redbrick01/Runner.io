import 'supabase_api.dart';

class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  Future<Map<String, dynamic>> fetchCurrentProfile() async {
    final decoded = await SupabaseApi.getFunctionJson('user-ranking');
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('user-ranking returned an invalid response');
    }
    return decoded;
  }

  Future<int?> fetchLeaderboardRank() async {
    final currentUser = SupabaseApi.currentUser;
    if (currentUser == null) return null;

    final decoded = await SupabaseApi.getFunctionJson(
      'profile-leaderboard',
      queryParameters: {'mode': 'context', 'user_id': currentUser.id},
    );

    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final user = decoded['user'];
    if (user is Map<String, dynamic>) {
      final rank = user['rank'];
      if (rank is num) return rank.toInt();
      return int.tryParse(rank?.toString() ?? '');
    }

    return null;
  }

  Future<void> updateProfile({
    String? nickName,
    String? password,
    required String colorHex,
    double? heightCm,
    double? weightKg,
  }) async {
    final body = <String, dynamic>{'color_hex': colorHex};

    if (nickName != null && nickName.isNotEmpty) {
      body['nick_name'] = nickName;
    }

    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }

    if (heightCm != null) {
      body['height_cm'] = heightCm;
    }

    if (weightKg != null) {
      body['weight_kg'] = weightKg;
    }

    await SupabaseApi.postFunctionJson('update-profile', body: body);
  }
}
