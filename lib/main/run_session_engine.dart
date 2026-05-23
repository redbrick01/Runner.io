import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunRoutePoint {
  const RunRoutePoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.timestampMillis,
    this.startsNewSegment = false,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final int? timestampMillis;
  final bool startsNewSegment;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    if (altitude != null) 'altitude': altitude,
    if (timestampMillis != null) 'timestamp_millis': timestampMillis,
    if (startsNewSegment) 'starts_new_segment': true,
  };

  factory RunRoutePoint.fromJson(Map<dynamic, dynamic> json) {
    return RunRoutePoint(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      timestampMillis: (json['timestamp_millis'] as num?)?.toInt(),
      startsNewSegment: json['starts_new_segment'] as bool? ?? false,
    );
  }

  factory RunRoutePoint.fromPosition(Position position) {
    return RunRoutePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude.isFinite ? position.altitude : null,
      timestampMillis: position.timestamp.millisecondsSinceEpoch,
    );
  }

  factory RunRoutePoint.fromLatLng(LatLng point) {
    return RunRoutePoint(latitude: point.latitude, longitude: point.longitude);
  }

  RunRoutePoint copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    int? timestampMillis,
    bool? startsNewSegment,
  }) {
    return RunRoutePoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      timestampMillis: timestampMillis ?? this.timestampMillis,
      startsNewSegment: startsNewSegment ?? this.startsNewSegment,
    );
  }
}

List<List<RunRoutePoint>> splitRoutePointSegments(List<RunRoutePoint> points) {
  final segments = <List<RunRoutePoint>>[];
  var current = <RunRoutePoint>[];

  for (final point in points) {
    if (point.startsNewSegment && current.isNotEmpty) {
      if (current.length >= 2) {
        segments.add(current);
      }
      current = <RunRoutePoint>[];
    }
    current.add(point);
  }

  if (current.length >= 2) {
    segments.add(current);
  }

  return segments;
}

class RunSessionSnapshot {
  const RunSessionSnapshot({
    required this.runId,
    required this.startedAt,
    required this.isPaused,
    required this.accumulatedPausedMillis,
    required this.totalDistance,
    required this.currentSpeed,
    required this.totalAscent,
    required this.routePoints,
  });

  final String runId;
  final DateTime startedAt;
  final bool isPaused;
  final int accumulatedPausedMillis;
  final double totalDistance;
  final double currentSpeed;
  final double totalAscent;
  final List<RunRoutePoint> routePoints;
}

class RunSessionEngine {
  static const double _stationaryReportedSpeedThresholdMps = 1.1;
  static const double _stationaryDerivedSpeedThresholdMps = 1.4;
  static const double _accuracyAllowanceMultiplier = 0.9;
  static const double _resumeSplitDistanceMeters = 50.0;

  RunSessionEngine({
    required this.maxAcceptedAccuracyMeters,
    required this.minMovementMeters,
    required this.maxDerivedSpeedMps,
    required this.warmupSampleCount,
  });

  final double maxAcceptedAccuracyMeters;
  final double minMovementMeters;
  final double maxDerivedSpeedMps;
  final int warmupSampleCount;

  bool isStarted = false;
  bool isPaused = false;
  DateTime? _startTime;
  DateTime? _pausedAt;
  Duration _accumulatedPausedDuration = Duration.zero;
  int elapsedSeconds = 0;
  double totalDistance = 0.0;
  double currentSpeed = 0.0;
  double totalAscent = 0.0;
  String? currentRunId;
  Position? _lastPosition;
  LatLng? _pausedReferencePoint;
  LatLng? _pendingSplitReferencePoint;
  int _warmupSamplesRemaining = 0;
  bool _shouldStartNewSegment = false;
  final List<RunRoutePoint> routePoints = [];

  DateTime? get startTime => _startTime;

  RunSessionSnapshot? createSnapshot() {
    final startedAt = _startTime;
    final runId = currentRunId;
    if (!isStarted || startedAt == null || runId == null) {
      return null;
    }

    var pausedMillis = _accumulatedPausedDuration.inMilliseconds;
    if (isPaused && _pausedAt != null) {
      pausedMillis += DateTime.now().difference(_pausedAt!).inMilliseconds;
    }

    return RunSessionSnapshot(
      runId: runId,
      startedAt: startedAt,
      isPaused: isPaused,
      accumulatedPausedMillis: pausedMillis,
      totalDistance: totalDistance,
      currentSpeed: currentSpeed,
      totalAscent: totalAscent,
      routePoints: List<RunRoutePoint>.from(routePoints),
    );
  }

  void prepareForCountdown() {
    routePoints.clear();
    totalDistance = 0.0;
    totalAscent = 0.0;
    elapsedSeconds = 0;
    currentSpeed = 0.0;
    _lastPosition = null;
    _warmupSamplesRemaining = warmupSampleCount;
  }

  void beginRun({LatLng? currentPosition}) {
    isStarted = true;
    isPaused = false;
    currentRunId = DateTime.now().millisecondsSinceEpoch.toString();
    elapsedSeconds = 0;
    totalDistance = 0.0;
    totalAscent = 0.0;
    currentSpeed = 0.0;
    _startTime = DateTime.now();
    _pausedAt = null;
    _accumulatedPausedDuration = Duration.zero;
    _warmupSamplesRemaining = warmupSampleCount;
    routePoints.clear();
    if (currentPosition != null) {
      routePoints.add(
        RunRoutePoint.fromLatLng(
          currentPosition,
        ).copyWith(startsNewSegment: true),
      );
    }
  }

  void pause() {
    if (!isStarted || isPaused) {
      return;
    }
    isPaused = true;
    _pausedAt = DateTime.now();
    if (routePoints.isNotEmpty) {
      _pausedReferencePoint = routePoints.last.latLng;
    } else if (_lastPosition != null) {
      _pausedReferencePoint = LatLng(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
      );
    } else {
      _pausedReferencePoint = null;
    }
  }

  void resume({LatLng? currentPosition}) {
    if (!isStarted || !isPaused) {
      return;
    }
    if (_pausedAt != null) {
      _accumulatedPausedDuration += DateTime.now().difference(_pausedAt!);
    }
    _pausedAt = null;
    isPaused = false;
    _lastPosition = null;
    _warmupSamplesRemaining = warmupSampleCount;
    _pendingSplitReferencePoint = _pausedReferencePoint;
    _shouldStartNewSegment = false;
    currentSpeed = 0.0;
    _pausedReferencePoint = null;
  }

  bool refreshElapsed() {
    if (!isStarted || _startTime == null) {
      return false;
    }

    final now = DateTime.now();
    final effectiveNow = isPaused && _pausedAt != null ? _pausedAt! : now;
    final elapsed =
        effectiveNow.difference(_startTime!) - _accumulatedPausedDuration;
    final nextSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
    if (elapsedSeconds == nextSeconds) {
      return false;
    }
    elapsedSeconds = nextSeconds;
    return true;
  }

  void primeWarmupPosition(Position position) {
    if (position.accuracy > maxAcceptedAccuracyMeters) {
      return;
    }

    if (_warmupSamplesRemaining > 0) {
      _warmupSamplesRemaining--;
    }

    _lastPosition = position;
  }

  bool addPositionSample(Position position, RunRoutePoint routePoint) {
    if (!isStarted || isPaused) {
      return false;
    }

    final acceptedSegmentDistance = _acceptedSegmentDistance(position);
    if (acceptedSegmentDistance == null) {
      return false;
    }

    final pendingReference = _pendingSplitReferencePoint;
    if (pendingReference != null) {
      _shouldStartNewSegment = _shouldSplitAfterResume(
        pausedPoint: pendingReference,
        resumedPoint: routePoint.latLng,
      );
      _pendingSplitReferencePoint = null;
    }

    routePoints.add(
      routePoint.copyWith(startsNewSegment: _shouldStartNewSegment),
    );
    _shouldStartNewSegment = false;
    totalDistance += acceptedSegmentDistance;
    totalAscent += _positiveAltitudeGain(_lastPosition, position);
    currentSpeed = _derivedSpeed(
      _lastPosition!,
      position,
      acceptedSegmentDistance,
    );
    _lastPosition = position;
    return true;
  }

  void reset() {
    isStarted = false;
    isPaused = false;
    _startTime = null;
    _pausedAt = null;
    _accumulatedPausedDuration = Duration.zero;
    elapsedSeconds = 0;
    totalDistance = 0.0;
    totalAscent = 0.0;
    currentSpeed = 0.0;
    currentRunId = null;
    _lastPosition = null;
    _pausedReferencePoint = null;
    _pendingSplitReferencePoint = null;
    _warmupSamplesRemaining = 0;
    _shouldStartNewSegment = false;
    routePoints.clear();
  }

  void restore(RunSessionSnapshot snapshot) {
    isStarted = true;
    isPaused = snapshot.isPaused;
    _startTime = snapshot.startedAt;
    _pausedAt = snapshot.isPaused ? DateTime.now() : null;
    _accumulatedPausedDuration = Duration(
      milliseconds: snapshot.accumulatedPausedMillis,
    );
    totalDistance = snapshot.totalDistance;
    totalAscent = snapshot.totalAscent;
    currentSpeed = snapshot.isPaused ? 0.0 : snapshot.currentSpeed;
    currentRunId = snapshot.runId;
    _lastPosition = null;
    _pausedReferencePoint = snapshot.routePoints.isNotEmpty
        ? snapshot.routePoints.last.latLng
        : null;
    _pendingSplitReferencePoint = snapshot.isPaused
        ? _pausedReferencePoint
        : null;
    _warmupSamplesRemaining = warmupSampleCount;
    _shouldStartNewSegment = false;
    routePoints
      ..clear()
      ..addAll(snapshot.routePoints);
    refreshElapsed();
  }

  double? _acceptedSegmentDistance(Position position) {
    if (position.accuracy > maxAcceptedAccuracyMeters) {
      return null;
    }

    if (_warmupSamplesRemaining > 0) {
      _warmupSamplesRemaining--;
      _lastPosition = position;
      return null;
    }

    final previousPosition = _lastPosition;
    if (previousPosition == null) {
      _lastPosition = position;
      return null;
    }

    final distance = Geolocator.distanceBetween(
      previousPosition.latitude,
      previousPosition.longitude,
      position.latitude,
      position.longitude,
    );
    final accuracyAllowance = _accuracyAllowance(previousPosition, position);
    final adjustedDistance = distance - accuracyAllowance;
    if (adjustedDistance < minMovementMeters) {
      return null;
    }

    final derivedSpeed = _derivedSpeed(previousPosition, position, distance);
    if (_looksLikeStationaryDrift(
      previousPosition: previousPosition,
      position: position,
      rawDistance: distance,
      adjustedDistance: adjustedDistance,
      derivedSpeed: derivedSpeed,
    )) {
      return null;
    }
    if (derivedSpeed > maxDerivedSpeedMps) {
      return null;
    }

    // `adjustedDistance` is only used for movement/noise gating.
    // Using it directly for cumulative distance can severely undercount
    // real movement when GPS accuracy is modest (common in city runs).
    return distance;
  }

  double _derivedSpeed(
    Position previousPosition,
    Position position,
    double distance,
  ) {
    final previousTimestamp = previousPosition.timestamp;
    final currentTimestamp = position.timestamp;
    final elapsedSeconds =
        currentTimestamp.difference(previousTimestamp).inMilliseconds / 1000;
    if (elapsedSeconds <= 0) {
      return position.speed >= 0 ? position.speed : 0.0;
    }

    return distance / elapsedSeconds;
  }

  double _positiveAltitudeGain(Position? previousPosition, Position position) {
    if (previousPosition == null) {
      return 0.0;
    }

    final previousAltitude = previousPosition.altitude;
    final currentAltitude = position.altitude;
    if (!previousAltitude.isFinite || !currentAltitude.isFinite) {
      return 0.0;
    }

    final delta = currentAltitude - previousAltitude;
    if (delta <= 0) {
      return 0.0;
    }

    return delta;
  }

  double _accuracyAllowance(Position previousPosition, Position position) {
    final previousAccuracy = previousPosition.accuracy.isFinite
        ? previousPosition.accuracy
        : maxAcceptedAccuracyMeters;
    final currentAccuracy = position.accuracy.isFinite
        ? position.accuracy
        : maxAcceptedAccuracyMeters;
    return previousAccuracy > currentAccuracy
        ? previousAccuracy * _accuracyAllowanceMultiplier
        : currentAccuracy * _accuracyAllowanceMultiplier;
  }

  bool _shouldSplitAfterResume({
    required LatLng? pausedPoint,
    required LatLng? resumedPoint,
  }) {
    if (pausedPoint == null || resumedPoint == null) {
      return false;
    }
    final movedMeters = Geolocator.distanceBetween(
      pausedPoint.latitude,
      pausedPoint.longitude,
      resumedPoint.latitude,
      resumedPoint.longitude,
    );
    return movedMeters >= _resumeSplitDistanceMeters;
  }

  bool _looksLikeStationaryDrift({
    required Position previousPosition,
    required Position position,
    required double rawDistance,
    required double adjustedDistance,
    required double derivedSpeed,
  }) {
    final reportedSpeed = position.speed.isFinite && position.speed >= 0
        ? position.speed
        : derivedSpeed;
    final driftWindow =
        _accuracyAllowance(previousPosition, position) + minMovementMeters;
    return reportedSpeed < _stationaryReportedSpeedThresholdMps &&
        derivedSpeed < _stationaryDerivedSpeedThresholdMps &&
        rawDistance <= driftWindow &&
        adjustedDistance <= minMovementMeters * 2;
  }
}
