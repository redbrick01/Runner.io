class RunSavePayload {
  const RunSavePayload({
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.point,
    required this.avgPaceSecondsPerKm,
    required this.calories,
    required this.totalAscentMeters,
    required this.segmentedPathGeom,
    required this.flattenedPathGeom,
    required this.splits,
    required this.routePoints,
  });

  final DateTime? startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double point;
  final double avgPaceSecondsPerKm;
  final double? calories;
  final double totalAscentMeters;
  final String segmentedPathGeom;
  final String flattenedPathGeom;
  final List<Map<String, dynamic>> splits;
  final List<Map<String, dynamic>> routePoints;

  Map<String, dynamic> toResultData() {
    return {
      'started_at': startedAt?.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'duration': durationSeconds,
      'distance': distanceMeters,
      'point': point,
      'avg_pace': avgPaceSecondsPerKm,
      'calories': calories,
      'total_ascent': totalAscentMeters,
      'path_geom': segmentedPathGeom,
      'splits': splits,
      'route_points': routePoints,
    };
  }

  Map<String, dynamic> toCreateRunBody({required String pathGeom}) {
    return {
      'started_at': startedAt?.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'duration': durationSeconds,
      'distance': distanceMeters,
      'point': point,
      'avg_pace': avgPaceSecondsPerKm,
      'calories': calories,
      'path_geom': pathGeom,
      'splits': splits,
    };
  }
}
