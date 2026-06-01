import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/services/social_service.dart';

void main() {
  group('SocialService models', () {
    test('parses friend code response', () {
      final code = FriendCodeResponse.fromJson({'friend_code': 'AB12CD34'});

      expect(code.friendCode, 'AB12CD34');
    });

    test('parses friend lookup result', () {
      final profile = FriendProfile.fromJson({
        'user_id': 'user-1',
        'nick_name': 'Runner Kim',
        'color_hex': '#2364AA',
        'friend_code': 'EF56GH78',
      });

      expect(profile.userId, 'user-1');
      expect(profile.nickName, 'Runner Kim');
      expect(profile.colorHex, '#2364AA');
      expect(profile.friendCode, 'EF56GH78');
    });

    test('parses incoming request row', () {
      final request = IncomingFriendRequest.fromJson({
        'friendship_id': 'friendship-1',
        'created_at': '2026-06-01T09:00:00Z',
        'requester': {
          'user_id': 'user-2',
          'nick_name': 'Park',
          'color_hex': '#F45B69',
        },
      });

      expect(request.friendshipId, 'friendship-1');
      expect(request.createdAt, DateTime.parse('2026-06-01T09:00:00Z'));
      expect(request.requester.userId, 'user-2');
      expect(request.requester.nickName, 'Park');
    });

    test('parses friend ranking item', () {
      final item = FriendRankingItem.fromJson({
        'user_id': 'user-3',
        'nick_name': 'Lee',
        'color_hex': '#00A676',
        'total_points': '123.5',
        'display_rank': '2',
        'is_self': false,
      });

      expect(item.userId, 'user-3');
      expect(item.totalPoints, 123.5);
      expect(item.displayRank, 2);
      expect(item.isSelf, isFalse);
    });
  });
}
