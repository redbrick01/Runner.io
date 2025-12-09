import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 러닝 1회에 대한 결과 (UI용)
class RunResult {
  final DateTime startAt;
  final DateTime endAt;
  final double distanceMeters;
  final Duration duration;
  final List<LatLng> route;

  // UI용 부가 정보
  final double calories;
  final double areaKm2;
  final double point; // 서버로 보낼 포인트 값

  const RunResult({
    required this.startAt,
    required this.endAt,
    required this.distanceMeters,
    required this.duration,
    required this.route,
    this.calories = 0,
    this.areaKm2 = 0,
    this.point = 0,
  });

  double get distanceKm => distanceMeters / 1000.0;

  double get durationMinutes => duration.inSeconds / 60.0;

  String get durationText {
    final m = duration.inMinutes.toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get avgPaceText {
    if (distanceKm == 0) return '00:00';
    final paceSec = duration.inSeconds / distanceKm;
    final total = paceSec.round();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Supabase Edge Function `run-create` 요청 DTO
class RunCreateRequest {
  /// ISO8601 문자열로 보낼 거라 String 타입으로
  final String startedAt;
  final String endedAt;
  final int duration; // 초 단위
  final double distance; // 미터
  final double point; // 점수
  /// PostGIS가 받는 WKT + SRID 문자열
  /// 예) "SRID=4326;LINESTRING(127.1 37.4, 127.2 37.41, ...)"
  final String pathGeom;

  const RunCreateRequest({
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.distance,
    required this.point,
    required this.pathGeom,
  });

  Map<String, dynamic> toJson() {
    return {
      'started_at': startedAt,
      'ended_at': endedAt,
      'duration': duration,
      'distance': distance,
      'point': point,
      'path_geom': pathGeom,
    };
  }
}

extension RunResultMapping on RunResult {
  RunCreateRequest toRunCreateRequest() {
    return RunCreateRequest(
      startedAt: startAt.toUtc().toIso8601String(),
      endedAt: endAt.toUtc().toIso8601String(),
      duration: duration.inSeconds,
      distance: distanceMeters,
      point: point,
      pathGeom: _toLineStringWkt(route),
    );
  }

  /// route(List<LatLng>)을 WKT(LineString) + SRID 문자열로 변환
  ///
  /// 결과 예:
  /// SRID=4326;LINESTRING(127.12784 37.44917, 127.12803 37.44905, ...)
  String _toLineStringWkt(List<LatLng> points) {
    if (points.length < 2) {
      // 최소 두 점은 있어야 라인이 됨
      throw Exception('route must contain at least 2 points');
    }

    final coordText = points
        .map((p) => '${p.longitude} ${p.latitude}') // (lon lat)
        .join(', ');

    return 'SRID=4326;LINESTRING($coordText)';
  }
}
