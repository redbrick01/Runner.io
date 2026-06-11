import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/running_map_page.dart';
import 'package:runner_flutter/services/crew_service.dart';

void main() {
  group('running map crew contribution selection', () {
    test('prefers default contribution crew', () {
      final crews = [
        _crew(id: 'crew-1', isDefaultContribution: false),
        _crew(id: 'crew-2', isDefaultContribution: true),
      ];

      expect(defaultCrewContributionIdFor(crews), 'crew-2');
    });

    test('falls back to first joined crew', () {
      final crews = [
        _crew(id: 'crew-1', isDefaultContribution: false),
        _crew(id: 'crew-2', isDefaultContribution: false),
      ];

      expect(defaultCrewContributionIdFor(crews), 'crew-1');
    });

    test('returns null when no joined crews are available', () {
      final crews = [
        _crew(id: 'crew-1', isJoined: false, isDefaultContribution: true),
      ];

      expect(defaultCrewContributionIdFor(crews), isNull);
    });

    test('finds selected crew summary for crew competition banner', () {
      final crews = [
        _crew(id: 'crew-1', isDefaultContribution: false),
        _crew(
          id: 'crew-2',
          isDefaultContribution: true,
          seasonScore: 42,
          cumulativeAreaM2: 2500000,
          displayRank: 3,
        ),
      ];

      final summary = crewSummaryForTopBanner(crews, 'crew-2');

      expect(summary?.id, 'crew-2');
      expect(summary?.seasonScore, 42);
      expect(summary?.cumulativeAreaM2, 2500000);
      expect(summary?.displayRank, 3);
    });
  });
}

CrewSummary _crew({
  required String id,
  bool isJoined = true,
  required bool isDefaultContribution,
  double seasonScore = 0,
  double cumulativeAreaM2 = 0,
  int? displayRank,
}) {
  return CrewSummary(
    id: id,
    name: id,
    memberCount: 1,
    seasonScore: seasonScore,
    cumulativeAreaM2: cumulativeAreaM2,
    isJoined: isJoined,
    isDefaultContribution: isDefaultContribution,
    displayRank: displayRank,
  );
}
