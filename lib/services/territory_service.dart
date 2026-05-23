import 'supabase_api.dart';

class TerritoryService {
  TerritoryService._();

  static final TerritoryService instance = TerritoryService._();

  Future<dynamic> fetchTerritories({
    required String bbox,
    int limit = 100,
  }) {
    return SupabaseApi.getFunctionJson(
      'territory-geojson',
      queryParameters: {
        'bbox': bbox,
        'limit': limit,
      },
    );
  }
}
