import 'package:supabase_flutter/supabase_flutter.dart';

class RankUser {
  final String nickname;
  final double totalPoints;
  final String colorHex;
  final String? avatarUrl;

  RankUser({
    required this.nickname,
    required this.totalPoints,
    required this.colorHex,
    this.avatarUrl,
  });

  factory RankUser.fromJson(Map<String, dynamic> json) {
    return RankUser(
      nickname: json['nick_name'] ?? 'Unknown',
      totalPoints: (json['total_points'] ?? 0).toDouble(),
      colorHex: json['color_hex'] ?? '#FFD700',
      avatarUrl: json['avatar_url'],
    );
  }
}

class RankService {
  final supabase = Supabase.instance.client;

  Future<List<RankUser>> loadRankers() async {
    final res = await supabase
        .from('profiles_old')
        .select()
        .order('total_points', ascending: false);

    final list = (res as List).map((e) => RankUser.fromJson(e)).toList();
    return list;
  }
}
