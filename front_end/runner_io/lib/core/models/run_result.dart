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
    final paceMin = duration.inSeconds / 60 / distanceKm;
    final pMin = paceMin.floor().toString().padLeft(2, '0');
    final pSec = ((paceMin - paceMin.floor()) * 60).round().toString().padLeft(
      2,
      '0',
    );
    return '$pMin:$pSec';
  }
}

/// Supabase Edge Function `/run-create` 요청 DTO
class RunCreateRequest {
  final DateTime startAt;
  final DateTime endedAt;
  final double durationMinutes;
  final double distanceMeters;
  final double point;
  final List<LatLng> route;

  const RunCreateRequest({
    required this.startAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.distanceMeters,
    required this.point,
    required this.route,
  });

  Map<String, dynamic> toJson() {
    return {
      'start_at': startAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'duration': durationMinutes,
      'distance': distanceMeters,
      'point': point,
      'path_geom': _toWktLineString(route),
    };
  }

  /// LatLng 리스트 → LINESTRING WKT (lon lat 순)
  String _toWktLineString(List<LatLng> points) {
    if (points.isEmpty) return 'LINESTRING EMPTY';
    final coords = points.map((p) => '${p.longitude} ${p.latitude}').join(', ');
    return 'LINESTRING($coords)';
  }
}

/// UI 모델 → 요청 DTO 변환
extension RunResultMapping on RunResult {
  RunCreateRequest toRunCreateRequest() {
    return RunCreateRequest(
      startAt: startAt,
      endedAt: endAt,
      durationMinutes: durationMinutes,
      distanceMeters: distanceMeters,
      point: point,
      route: route,
    );
  }
}
