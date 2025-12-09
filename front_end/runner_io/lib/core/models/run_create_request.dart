class RunCreateRequest {
  final String startedAt; // ISO8601 문자열
  final String endedAt; // ISO8601 문자열
  final int duration; // 초 단위
  final double distance; // 미터
  final double point; // 초기 점수
  final String pathGeom;

  RunCreateRequest({
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
