import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/services/run_save_payload.dart';

void main() {
  test('builds create-run body without result-only route fields', () {
    final startedAt = DateTime.utc(2026, 5, 24, 1);
    final endedAt = DateTime.utc(2026, 5, 24, 1, 30);
    final payload = RunSavePayload(
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: 1800,
      distanceMeters: 5000,
      point: 52.5,
      avgPaceSecondsPerKm: 360,
      calories: 310,
      totalAscentMeters: 42,
      segmentedPathGeom: 'MULTILINESTRING Z ((127 37 10, 127.1 37.1 12))',
      flattenedPathGeom: 'LINESTRING Z (127 37 10, 127.1 37.1 12)',
      splits: const [
        {'split_index': 1, 'distance_m': 1000, 'duration_s': 360},
      ],
      routePoints: const [
        {'latitude': 37.0, 'longitude': 127.0},
      ],
    );

    final body = payload.toCreateRunBody(pathGeom: payload.flattenedPathGeom);

    expect(body['started_at'], startedAt.toIso8601String());
    expect(body['ended_at'], endedAt.toIso8601String());
    expect(body['path_geom'], payload.flattenedPathGeom);
    expect(body['splits'], payload.splits);
    expect(body.containsKey('route_points'), isFalse);
    expect(body.containsKey('total_ascent'), isFalse);
  });

  test('builds result data with client-only route metadata', () {
    final payload = RunSavePayload(
      startedAt: null,
      endedAt: DateTime.utc(2026, 5, 24, 1, 30),
      durationSeconds: 1800,
      distanceMeters: 5000,
      point: 52.5,
      avgPaceSecondsPerKm: 360,
      calories: null,
      totalAscentMeters: 42,
      segmentedPathGeom: 'MULTILINESTRING Z ((127 37 10, 127.1 37.1 12))',
      flattenedPathGeom: 'LINESTRING Z (127 37 10, 127.1 37.1 12)',
      splits: const [],
      routePoints: const [
        {'latitude': 37.0, 'longitude': 127.0},
      ],
    );

    final result = payload.toResultData();

    expect(result['started_at'], isNull);
    expect(result['route_points'], payload.routePoints);
    expect(result['total_ascent'], 42);
    expect(result['path_geom'], payload.segmentedPathGeom);
  });
}
