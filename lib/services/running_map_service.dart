import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'territory_service.dart';
import 'user_profile_store.dart';

class RunningMapService {
  RunningMapService._();

  static final RunningMapService instance = RunningMapService._();

  Future<UserProfileSnapshot?> fetchUserProfile({bool force = false}) {
    return UserProfileStore.instance.fetch(force: force);
  }

  Future<dynamic> fetchTerritories({
    required GoogleMapController? mapController,
    required LatLng? currentPosition,
    int limit = 100,
    TerritoryScope? scope,
    String? crewId,
  }) async {
    final bbox = await _resolveBbox(
      mapController: mapController,
      currentPosition: currentPosition,
    );
    if (bbox == null) {
      return null;
    }

    return TerritoryService.instance.fetchTerritories(
      bbox: bbox,
      limit: limit,
      scope: scope,
      crewId: crewId,
    );
  }

  Future<String?> _resolveBbox({
    required GoogleMapController? mapController,
    required LatLng? currentPosition,
  }) async {
    if (mapController != null) {
      final LatLngBounds bounds = await mapController.getVisibleRegion();
      return '${bounds.southwest.longitude},${bounds.southwest.latitude},${bounds.northeast.longitude},${bounds.northeast.latitude}';
    }

    if (currentPosition == null) {
      return null;
    }

    final lat = currentPosition.latitude;
    final lng = currentPosition.longitude;
    return '${lng - 0.02},${lat - 0.02},${lng + 0.02},${lat + 0.02}';
  }
}
