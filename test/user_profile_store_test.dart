import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/services/user_profile_store.dart';

void main() {
  group('UserProfileSnapshot', () {
    test('marks a null data response as missing identity data', () {
      final snapshot = UserProfileSnapshot.fromResponseMap({'data': null});

      expect(snapshot.hasIdentityData, isFalse);
      expect(snapshot.rank, 0);
      expect(snapshot.area, 0);
      expect(snapshot.totalPoints, 0);
    });

    test('parses dashboard profile values from user-ranking response', () {
      final snapshot = UserProfileSnapshot.fromResponseMap({
        'data': {
          'rank': 7,
          'area': 1234567.0,
          'profile': {
            'id': 10,
            'nick_name': 'runner',
            'total_points': 42.5,
            'color_hex': '#0090FF',
            'user_id': 'user-1',
          },
        },
      });

      expect(snapshot.hasIdentityData, isTrue);
      expect(snapshot.rank, 7);
      expect(snapshot.area, 1234567.0);
      expect(snapshot.totalPoints, 42.5);
      expect(snapshot.userId, 'user-1');
    });
  });
}
