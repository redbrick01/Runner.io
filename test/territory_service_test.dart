import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/services/territory_service.dart';

void main() {
  group('TerritoryQuery', () {
    test('includes only existing bbox and limit by default', () {
      final result = const TerritoryQuery(
        bbox: '126.9,37.4,127.1,37.6',
        limit: 100,
      ).toQueryParameters();

      expect(result, {
        'bbox': '126.9,37.4,127.1,37.6',
        'limit': 100,
      });
    });

    test('sends scope and crew id when provided', () {
      final result = const TerritoryQuery(
        bbox: '126.9,37.4,127.1,37.6',
        limit: 100,
        scope: TerritoryScope.crew,
        crewId: 'crew-1',
      ).toQueryParameters();

      expect(result['scope'], 'crew');
      expect(result['crew_id'], 'crew-1');
    });
  });
}
