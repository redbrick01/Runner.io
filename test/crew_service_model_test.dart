import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/services/crew_service.dart';

void main() {
  group('CrewService models', () {
    test('parses crew summary from json', () {
      final crew = CrewSummary.fromJson({
        'id': 'crew-1',
        'name': 'Gangnam Runners',
        'description': 'Territory crew',
        'region': 'Gangnam',
        'color_hex': '#2364AA',
        'member_count': 12,
        'season_score': 123.5,
        'cumulative_area_m2': 4567.0,
        'is_joined': true,
        'is_default_contribution': false,
      });

      expect(crew.id, 'crew-1');
      expect(crew.name, 'Gangnam Runners');
      expect(crew.memberCount, 12);
      expect(crew.seasonScore, 123.5);
      expect(crew.isJoined, isTrue);
      expect(crew.isDefaultContribution, isFalse);
    });

    test('parses crew detail member contribution', () {
      final member = CrewMemberContribution.fromJson({
        'user_id': 'user-1',
        'nick_name': 'Runner Kim',
        'color_hex': '#F45B69',
        'contribution_score': '81.25',
        'contribution_area_m2': 1200,
        'display_rank': '3',
      });

      expect(member.userId, 'user-1');
      expect(member.nickName, 'Runner Kim');
      expect(member.contributionScore, 81.25);
      expect(member.contributionAreaM2, 1200);
      expect(member.displayRank, 3);
    });

    test('parses crew detail response', () {
      final detail = CrewDetail.fromJson({
        'season': {
          'season_type': 'week',
          'anchor_date': '2026-06-01',
          'from': '2026-06-01',
          'to': '2026-06-07',
        },
        'crew': {
          'id': 'crew-1',
          'name': 'Gangnam Runners',
          'description': null,
          'region': 'Gangnam',
          'color_hex': '#2364AA',
          'member_count': 12,
          'season_score': 123.5,
          'cumulative_area_m2': 4567,
          'is_joined': true,
          'is_default_contribution': true,
        },
        'can_view_members': true,
        'members': [
          {
            'user_id': 'user-1',
            'nick_name': 'Runner Kim',
            'color_hex': '#F45B69',
            'contribution_score': 81.25,
            'contribution_area_m2': 1200,
            'display_rank': 1,
          },
        ],
      });

      expect(detail.season.seasonType, 'week');
      expect(detail.crew.name, 'Gangnam Runners');
      expect(detail.canViewMembers, isTrue);
      expect(detail.members.single.displayRank, 1);
    });
  });
}
