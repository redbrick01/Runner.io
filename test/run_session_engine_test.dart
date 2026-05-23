import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runner_flutter/main/run_session_engine.dart';

void main() {
  group('RunSessionEngine', () {
    test('accepts valid movement and updates distance, speed, and ascent', () {
      final engine = _engine();
      final start = DateTime(2026);

      engine.beginRun(currentPosition: const LatLng(37.0, 127.0));

      expect(
        engine.addPositionSample(
          _position(
            latitude: 37.0,
            longitude: 127.0,
            altitude: 10,
            timestamp: start,
          ),
          const RunRoutePoint(latitude: 37.0, longitude: 127.0, altitude: 10),
        ),
        isFalse,
      );

      expect(
        engine.addPositionSample(
          _position(
            latitude: 37.0,
            longitude: 127.001,
            altitude: 18,
            timestamp: start.add(const Duration(seconds: 10)),
          ),
          const RunRoutePoint(latitude: 37.0, longitude: 127.001, altitude: 18),
        ),
        isTrue,
      );

      expect(engine.routePoints, hasLength(2));
      expect(engine.totalDistance, greaterThan(80));
      expect(engine.totalDistance, lessThan(100));
      expect(engine.currentSpeed, closeTo(engine.totalDistance / 10, 0.01));
      expect(engine.totalAscent, 8);
    });

    test('rejects inaccurate samples without moving the session forward', () {
      final engine = _engine(maxAcceptedAccuracyMeters: 20);

      engine.beginRun();

      expect(
        engine.addPositionSample(
          _position(latitude: 37.0, longitude: 127.0, accuracy: 30),
          const RunRoutePoint(latitude: 37.0, longitude: 127.0),
        ),
        isFalse,
      );

      expect(engine.totalDistance, 0);
      expect(engine.routePoints, isEmpty);
    });

    test('starts a new route segment after resuming far from pause point', () {
      final engine = _engine();
      final start = DateTime(2026);

      engine.beginRun(currentPosition: const LatLng(37.0, 127.0));
      engine.addPositionSample(
        _position(latitude: 37.0, longitude: 127.0, timestamp: start),
        const RunRoutePoint(latitude: 37.0, longitude: 127.0),
      );
      engine.addPositionSample(
        _position(
          latitude: 37.0,
          longitude: 127.001,
          timestamp: start.add(const Duration(seconds: 10)),
        ),
        const RunRoutePoint(latitude: 37.0, longitude: 127.001),
      );

      engine.pause();
      engine.resume();

      engine.addPositionSample(
        _position(
          latitude: 37.002,
          longitude: 127.002,
          timestamp: start.add(const Duration(seconds: 20)),
        ),
        const RunRoutePoint(latitude: 37.002, longitude: 127.002),
      );
      engine.addPositionSample(
        _position(
          latitude: 37.002,
          longitude: 127.003,
          timestamp: start.add(const Duration(seconds: 30)),
        ),
        const RunRoutePoint(latitude: 37.002, longitude: 127.003),
      );
      engine.addPositionSample(
        _position(
          latitude: 37.002,
          longitude: 127.004,
          timestamp: start.add(const Duration(seconds: 40)),
        ),
        const RunRoutePoint(latitude: 37.002, longitude: 127.004),
      );

      expect(engine.routePoints.any((point) => point.startsNewSegment), isTrue);
      expect(splitRoutePointSegments(engine.routePoints), hasLength(2));
    });

    test('ignores samples while paused', () {
      final engine = _engine();
      final start = DateTime(2026);

      engine.beginRun();
      engine.addPositionSample(
        _position(latitude: 37.0, longitude: 127.0, timestamp: start),
        const RunRoutePoint(latitude: 37.0, longitude: 127.0),
      );
      engine.pause();

      expect(
        engine.addPositionSample(
          _position(
            latitude: 37.0,
            longitude: 127.001,
            timestamp: start.add(const Duration(seconds: 10)),
          ),
          const RunRoutePoint(latitude: 37.0, longitude: 127.001),
        ),
        isFalse,
      );

      expect(engine.totalDistance, 0);
      expect(engine.routePoints, isEmpty);
    });

    test('skips warmup samples before accepting movement', () {
      final engine = _engine(warmupSampleCount: 1);
      final start = DateTime(2026);

      engine.beginRun();

      expect(
        engine.addPositionSample(
          _position(latitude: 37.0, longitude: 127.0, timestamp: start),
          const RunRoutePoint(latitude: 37.0, longitude: 127.0),
        ),
        isFalse,
      );
      expect(
        engine.addPositionSample(
          _position(
            latitude: 37.0,
            longitude: 127.001,
            timestamp: start.add(const Duration(seconds: 10)),
          ),
          const RunRoutePoint(latitude: 37.0, longitude: 127.001),
        ),
        isTrue,
      );

      expect(engine.routePoints, hasLength(1));
      expect(engine.totalDistance, greaterThan(80));
    });

    test('rejects movement above the derived speed limit', () {
      final engine = _engine(maxDerivedSpeedMps: 5);
      final start = DateTime(2026);

      engine.beginRun();
      engine.addPositionSample(
        _position(latitude: 37.0, longitude: 127.0, timestamp: start),
        const RunRoutePoint(latitude: 37.0, longitude: 127.0),
      );

      expect(
        engine.addPositionSample(
          _position(
            latitude: 37.0,
            longitude: 127.001,
            timestamp: start.add(const Duration(seconds: 1)),
          ),
          const RunRoutePoint(latitude: 37.0, longitude: 127.001),
        ),
        isFalse,
      );

      expect(engine.totalDistance, 0);
      expect(engine.routePoints, isEmpty);
    });

    test('snapshot is only available for active runs', () {
      final engine = _engine();

      expect(engine.createSnapshot(), isNull);

      engine.beginRun(currentPosition: const LatLng(37.0, 127.0));

      final snapshot = engine.createSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.isPaused, isFalse);
      expect(snapshot.routePoints, hasLength(1));
    });
  });
}

RunSessionEngine _engine({
  double maxAcceptedAccuracyMeters = 30,
  double maxDerivedSpeedMps = 20,
  int warmupSampleCount = 0,
}) {
  return RunSessionEngine(
    maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
    minMovementMeters: 5,
    maxDerivedSpeedMps: maxDerivedSpeedMps,
    warmupSampleCount: warmupSampleCount,
  );
}

Position _position({
  required double latitude,
  required double longitude,
  DateTime? timestamp,
  double altitude = 0,
  double accuracy = 3,
  double speed = -1,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime(2026),
    accuracy: accuracy,
    altitude: altitude,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: speed,
    speedAccuracy: 1,
  );
}
