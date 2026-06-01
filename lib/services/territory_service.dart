import 'supabase_api.dart';

enum TerritoryScope {
  personal,
  friends,
  crew;

  String get queryValue => name;
}

class TerritoryQuery {
  const TerritoryQuery({
    required this.bbox,
    this.limit = 100,
    this.scope,
    this.crewId,
  });

  final String bbox;
  final int limit;
  final TerritoryScope? scope;
  final String? crewId;

  Map<String, dynamic> toQueryParameters() {
    return {
      'bbox': bbox,
      'limit': limit,
      if (scope != null) 'scope': scope!.queryValue,
      if (crewId != null && crewId!.trim().isNotEmpty)
        'crew_id': crewId!.trim(),
    };
  }
}

class TerritoryService {
  TerritoryService._();

  static final TerritoryService instance = TerritoryService._();

  Future<dynamic> fetchTerritories({
    required String bbox,
    int limit = 100,
    TerritoryScope? scope,
    String? crewId,
  }) {
    return SupabaseApi.getFunctionJson(
      'territory-geojson',
      queryParameters: TerritoryQuery(
        bbox: bbox,
        limit: limit,
        scope: scope,
        crewId: crewId,
      ).toQueryParameters(),
    );
  }
}
