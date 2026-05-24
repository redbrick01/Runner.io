import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../app_colors.dart';
import '../design/app_design.dart';
import '../services/run_ai_report_service.dart';
import 'running_map_page.dart';
import 'run_session_engine.dart';

class RunResultPage extends StatefulWidget {
  final Map<String, dynamic> runData;
  final Future<RunAiReport?> Function(int runId)? loadAiReport;
  final Future<RunAiReport?> Function(int runId)? generateAiReport;
  static const Color _metricValueColor = Color(0xFF2C2C2E);

  const RunResultPage({
    super.key,
    required this.runData,
    this.loadAiReport,
    this.generateAiReport,
  });

  @override
  State<RunResultPage> createState() => _RunResultPageState();
}

class _RunResultPageState extends State<RunResultPage> {
  RunRoutePoint? _selectedAltitudePoint;
  BitmapDescriptor? _selectedAltitudeMarkerIcon;
  bool _isAltitudeExpanded = false;
  RunAiReport? _aiReport;
  bool _isAiReportLoading = false;
  String? _aiReportError;

  @override
  void initState() {
    super.initState();
    _prepareSelectedAltitudeMarkerIcon();
    _fetchExistingAiReport();
  }

  Future<void> _fetchExistingAiReport() async {
    final runId = _asInt(widget.runData['id']);
    if (runId <= 0) return;

    try {
      final loader =
          widget.loadAiReport ??
          (int id) => RunAiReportService.instance.fetchRunReport(id);
      final report = await loader(runId);
      if (!mounted) return;
      setState(() {
        _aiReport = report;
      });
    } catch (_) {
      // 기존 리포트 조회 실패는 저장 결과 확인을 방해하지 않는다.
    }
  }

  Future<void> _generateAiReport() async {
    final runId = _asInt(widget.runData['id']);
    if (runId <= 0 || _isAiReportLoading) return;

    setState(() {
      _isAiReportLoading = true;
      _aiReportError = null;
    });

    try {
      final generator =
          widget.generateAiReport ??
          (int id) => RunAiReportService.instance.generateRunReport(id);
      final report = await generator(runId);
      if (!mounted) return;
      setState(() {
        _aiReport = report;
        _isAiReportLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiReportError = 'AI 분석을 생성하지 못했습니다.';
        _isAiReportLoading = false;
      });
    }
  }

  Future<void> _prepareSelectedAltitudeMarkerIcon() async {
    final icon = await _createDotIcon(AppColors.primary);
    if (!mounted) return;
    setState(() {
      _selectedAltitudeMarkerIcon = icon;
    });
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final local = parsed.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}.$mm.$dd $hh:$min';
  }

  String _formatDuration(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _calculatePace(double distanceMetres, int durationSeconds) {
    if (distanceMetres < 10) return "-'--\"";
    double distanceKm = distanceMetres / 1000;
    double paceDecimal = (durationSeconds / 60) / distanceKm;
    int m = paceDecimal.toInt();
    int s = ((paceDecimal - m) * 60).toInt();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  String _formatPoint(dynamic point) {
    if (point == null) return "0";
    double val = point.toDouble();
    if (val == val.toInt()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  String _formatAscent(double metres) {
    if (metres <= 0) return "0 m";
    if (metres >= 100) return "${metres.toStringAsFixed(0)} m";
    return "${metres.toStringAsFixed(1)} m";
  }

  String _formatPaceSeconds(double secondsPerKm) {
    if (secondsPerKm <= 0) return "-'--\"";
    final totalSeconds = secondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  String _formatCaloriesValue(double? calories) {
    if (calories == null || !calories.isFinite) {
      return '-';
    }
    if (calories <= 0) {
      return '0';
    }
    return calories >= 10
        ? calories.toStringAsFixed(0)
        : calories.toStringAsFixed(1);
  }

  List<Map<String, dynamic>> _parseSplits(dynamic raw) {
    if (raw is! List) {
      return const [];
    }

    final splits = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    if (splits.isEmpty) {
      return const [];
    }

    final sorted = [...splits];
    sorted.sort(
      (a, b) => _asInt(a['split_index']).compareTo(_asInt(b['split_index'])),
    );
    return sorted;
  }

  LatLng? _extractTerritoryFocusPoint(Map<String, dynamic> runData) {
    final loopSegments = _segmentsFromGeometry(runData['loop_geom']);
    if (loopSegments.isNotEmpty) {
      final points = loopSegments.expand((segment) => segment).toList();
      if (points.isNotEmpty) {
        double minLat = points.first.latitude;
        double maxLat = points.first.latitude;
        double minLng = points.first.longitude;
        double maxLng = points.first.longitude;
        for (final point in points) {
          if (point.latitude < minLat) minLat = point.latitude;
          if (point.latitude > maxLat) maxLat = point.latitude;
          if (point.longitude < minLng) minLng = point.longitude;
          if (point.longitude > maxLng) maxLng = point.longitude;
        }
        return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      }
    }

    final pathSegments = _segmentsFromGeometry(runData['path_geom']);
    if (pathSegments.isNotEmpty && pathSegments.first.isNotEmpty) {
      final first = pathSegments.first.first;
      return LatLng(first.latitude, first.longitude);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final runData = widget.runData;
    final double distanceMetres = _asDouble(runData['distance']);
    final double distanceKm = distanceMetres / 1000;
    final int duration = _asInt(runData['duration']);
    final dynamic point = runData['point'] ?? 0;
    final double avgPace = _asDouble(runData['avg_pace']);
    final double? calories = _asNullableDouble(runData['calories']);
    final double savedTotalAscent = _asDouble(runData['total_ascent']);
    final double area = _asDouble(runData['area']);
    final double areaKm2 = area / 1000000;
    final splits = _parseSplits(runData['splits']);
    final List<dynamic> rawRoutePoints =
        (runData['route_points'] as List? ?? const []);
    final List<RunRoutePoint> routeSamples = rawRoutePoints.map((point) {
      if (point is Map) {
        return RunRoutePoint.fromJson(point);
      }
      if (point is LatLng) {
        return RunRoutePoint.fromLatLng(point);
      }
      throw ArgumentError('Unsupported route point format: $point');
    }).toList();
    final loopSegments = _segmentsFromGeometry(runData['loop_geom']);
    final pathSegments = _segmentsFromGeometry(runData['path_geom']);
    final List<List<RunRoutePoint>> routeSegments = routeSamples.isNotEmpty
        ? splitRoutePointSegments(routeSamples)
        : _geometrySegments(
            loopGeom: runData['loop_geom'],
            pathGeom: runData['path_geom'],
          );
    final List<List<RunRoutePoint>> geometrySegments = _geometrySegments(
      loopGeom: runData['loop_geom'],
      pathGeom: runData['path_geom'],
    );
    final bool geometryHasAltitude = _hasFiniteAltitude(geometrySegments);
    final bool routeHasAltitude = _hasFiniteAltitude(routeSegments);
    final List<List<RunRoutePoint>> ascentSegments = geometryHasAltitude
        ? geometrySegments
        : routeHasAltitude
        ? routeSegments
        : (geometrySegments.isNotEmpty ? geometrySegments : routeSegments);
    final bool hasAscentAltitude = _hasFiniteAltitude(ascentSegments);
    final double computedAscent = _calculateAscentFromSegments(ascentSegments);
    final double totalAscent = hasAscentAltitude
        ? computedAscent
        : savedTotalAscent;
    final List<LatLng> routePoints = routeSegments
        .expand((segment) => segment.map((point) => point.latLng))
        .toList(growable: false);
    final mapPolylines = _buildMapPolylines(
      routeSegments: routeSegments,
      pathSegments: pathSegments,
      loopSegments: loopSegments,
    );
    final mapPolygons = _buildLoopPolygons(loopSegments);
    final List<RunRoutePoint> altitudeSamples = _collectAltitudeSamples(
      ascentSegments,
    );
    final String paceText = avgPace > 0
        ? _calculatePace(1000, avgPace.round())
        : _calculatePace(distanceMetres, duration);
    final selectedAltitudePoint = _selectedAltitudePoint;
    final territoryFocusPoint = _extractTerritoryFocusPoint(runData);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '러닝 리포트',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 지도 영역 (경로 표시)
            SizedBox(
              height: 280,
              width: double.infinity,
              child: routePoints.isEmpty
                  ? const Center(
                      child: Text(
                        "경로 데이터가 없습니다.",
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    )
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: routePoints.first,
                        zoom: 15,
                      ),
                      polylines: mapPolylines,
                      polygons: mapPolygons,
                      markers: {
                        if (selectedAltitudePoint != null)
                          Marker(
                            markerId: const MarkerId('selected_altitude_point'),
                            position: selectedAltitudePoint.latLng,
                            icon:
                                _selectedAltitudeMarkerIcon ??
                                BitmapDescriptor.defaultMarker,
                            infoWindow: InfoWindow(
                              title: '선택한 고도 지점',
                              snippet: _formatRelativeAltitudeLabel(
                                (selectedAltitudePoint.altitude ?? 0) -
                                    (altitudeSamples.isNotEmpty
                                        ? (altitudeSamples.first.altitude ?? 0)
                                        : 0),
                              ),
                            ),
                          ),
                      },
                      onMapCreated: (controller) {
                        if (routePoints.isNotEmpty) {
                          double minLat = routePoints.first.latitude;
                          double maxLat = routePoints.first.latitude;
                          double minLng = routePoints.first.longitude;
                          double maxLng = routePoints.first.longitude;

                          for (var p in routePoints) {
                            if (p.latitude < minLat) minLat = p.latitude;
                            if (p.latitude > maxLat) maxLat = p.latitude;
                            if (p.longitude < minLng) minLng = p.longitude;
                            if (p.longitude > maxLng) maxLng = p.longitude;
                          }

                          controller.animateCamera(
                            CameraUpdate.newLatLngBounds(
                              LatLngBounds(
                                southwest: LatLng(minLat, minLng),
                                northeast: LatLng(maxLat, maxLng),
                              ),
                              50,
                            ),
                          );
                        }
                      },
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      buildingsEnabled: false,
                      trafficEnabled: false,
                      liteModeEnabled: true,
                    ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroCard(
                    title: "",
                    subtitle: _formatDateTime(runData['created_at']),
                    value: "${_formatPoint(point)} P",
                    caption: "",
                    icon: Icons.stars_rounded,
                  ),
                  const SizedBox(height: 28),
                  const Text("주요 기록", style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.directions_run_rounded,
                          label: "거리",
                          value: distanceKm.toStringAsFixed(2),
                          unit: "km",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.timer_outlined,
                          label: "시간",
                          value: _formatDuration(duration),
                          unit: "",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.speed_rounded,
                          label: "평균 페이스",
                          value: paceText,
                          unit: "",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.local_fire_department_outlined,
                          label: "칼로리",
                          value: _formatCaloriesValue(calories),
                          unit: "kcal",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSingleWideMetricCard(
                    icon: Icons.landscape_rounded,
                    label: "누적 상승",
                    value: _formatAscent(totalAscent),
                    onTap: () {
                      setState(() {
                        _isAltitudeExpanded = !_isAltitudeExpanded;
                      });
                    },
                    trailing: Icon(
                      _isAltitudeExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _isAltitudeExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: altitudeSamples.isNotEmpty
                                ? _buildAltitudeChartCard(altitudeSamples)
                                : _buildAltitudeUnavailableCard(),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (splits.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSplitSection(splits),
                  ],
                  if (_shouldShowAiReportSection) ...[
                    const SizedBox(height: 12),
                    _buildAiReportSection(),
                  ],
                  const SizedBox(height: 12),
                  _buildWideMetricCard(
                    icon: Icons.crop_square_rounded,
                    label: "점령 면적",
                    value: "${areaKm2.toStringAsFixed(2)} km²",
                    trailing: "${_formatPoint(point)} P",
                  ),
                  const SizedBox(height: 48),
                  if (area > 0 && territoryFocusPoint != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => RunningMapPage(
                                initialFocusTarget: territoryFocusPoint,
                              ),
                            ),
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          "지도에서 영토 보기",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "확인",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _shouldShowAiReportSection =>
      _asInt(widget.runData['id']) > 0 ||
      _isAiReportLoading ||
      _aiReport != null ||
      _aiReportError != null;

  Widget _buildAiReportSection() {
    final report = _aiReport;
    if (_isAiReportLoading && report == null) {
      return const AppSurface(
        color: AppColors.primarySoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI 분석을 생성 중입니다.',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              '현재 기록과 비슷한 과거 러닝을 찾고 코칭 문구를 만드는 중이에요. 잠시만 기다려 주세요.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (_aiReportError != null || report == null) {
      return AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _aiReportError ?? 'AI 러닝 분석',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _aiReportError == null
                  ? '현재 기록과 유사한 과거 러닝을 비교해 AI 요약, 개선점, 다음 목표, 코칭 문구를 생성합니다.'
                  : '네트워크나 서버 설정을 확인한 뒤 다시 시도해 주세요.',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isAiReportLoading ? null : _generateAiReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                label: Text(
                  _aiReportError == null ? 'AI 분석하기' : 'AI 분석 다시 시도',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppSurface(
      color: AppColors.primarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI 러닝 분석',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (report.similarRunCount > 0)
                Text(
                  '유사 ${report.similarRunCount}개',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            report.summary,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (report.improvements.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('개선점', style: AppTextStyles.label),
            const SizedBox(height: 6),
            ...report.improvements.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '- $item',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildAiReportPill(
            icon: Icons.flag_rounded,
            label: '다음 목표',
            value: report.nextGoalLabel,
          ),
          const SizedBox(height: 8),
          _buildAiReportPill(
            icon: Icons.chat_bubble_rounded,
            label: '코칭',
            value: report.coachingMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildAiReportPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  height: 1.32,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required String title,
    required String subtitle,
    required String value,
    required String caption,
    required IconData icon,
  }) {
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      radius: AppRadii.heroCard,
      shadow: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                if (title.isNotEmpty) const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    height: 1.0,
                  ),
                ),
                if (caption.isNotEmpty) const SizedBox(height: 4),
                if (caption.isNotEmpty)
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary, size: 34),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: RunResultPage._metricValueColor,
                    height: 1.0,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWideMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String trailing,
  }) {
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      radius: 22,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 17),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: RunResultPage._metricValueColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                trailing,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleWideMetricCard({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final card = AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: RunResultPage._metricValueColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: card,
    );
  }

  Widget _buildAltitudeChartCard(List<RunRoutePoint> altitudePoints) {
    final double baseAltitude = altitudePoints.first.altitude ?? 0;
    final List<double> relativeAltitudes = altitudePoints
        .map((point) => (point.altitude ?? baseAltitude) - baseAltitude)
        .toList(growable: false);
    final double minAltitude = relativeAltitudes.reduce(math.min);
    final double maxAltitude = relativeAltitudes.reduce(math.max);
    final double range = maxAltitude - minAltitude;
    final List<RunRoutePoint> sampledAltitudePoints;
    if (altitudePoints.length <= 36) {
      sampledAltitudePoints = altitudePoints;
    } else {
      sampledAltitudePoints = List<RunRoutePoint>.generate(36, (index) {
        final pointIndex = ((altitudePoints.length - 1) * index / 35).round();
        return altitudePoints[pointIndex];
      });
    }
    final List<double> sampledRelativeAltitudes = sampledAltitudePoints
        .map((point) => (point.altitude ?? baseAltitude) - baseAltitude)
        .toList(growable: false);

    return AppSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                "고도 변화",
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                "${_formatRelativeAltitudeLabel(minAltitude)} ~ ${_formatRelativeAltitudeLabel(maxAltitude)}",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(sampledAltitudePoints.length, (
                index,
              ) {
                final altitudePoint = sampledAltitudePoints[index];
                final altitude = sampledRelativeAltitudes[index];
                final double normalized = range <= 0
                    ? 0.45
                    : ((altitude - minAltitude) / range).clamp(0.0, 1.0);
                final double barHeight = 18 + (normalized * 66);
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectAltitudePoint(altitudePoint),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: barHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(
                            alpha: 0.22 + (normalized * 0.5),
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAltitudeUnavailableCard() {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: const Row(
        children: [
          Icon(Icons.terrain_outlined, color: AppColors.secondaryText),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '고도 데이터 없음 (GPS 고도 미포함 경로)',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitSection(List<Map<String, dynamic>> splits) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '구간 페이스 (km)',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...splits.map(_buildSplitRow),
        ],
      ),
    );
  }

  Widget _buildSplitRow(Map<String, dynamic> split) {
    final splitIndex = _asInt(split['split_index']);
    final distanceM = _asDouble(split['distance_m']);
    final durationS = _asDouble(split['duration_s']);
    final rawPace = _asDouble(split['avg_pace_s_per_km']);
    final rawSpeed = _asDouble(split['avg_speed_mps']);
    final pace = rawPace > 0
        ? rawPace
        : (distanceM > 0 ? durationS / (distanceM / 1000) : 0.0);
    final speedKmh = rawSpeed > 0
        ? rawSpeed * 3.6
        : (durationS > 0 ? (distanceM / durationS) * 3.6 : 0.0);
    final distanceLabel = '${(distanceM / 1000).toStringAsFixed(2)}km';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '$splitIndex',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatPaceSeconds(pace),
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _formatDuration(durationS.round()),
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${speedKmh.toStringAsFixed(1)}km/h',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            distanceLabel,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Set<Polyline> _buildMapPolylines({
    required List<List<RunRoutePoint>> routeSegments,
    required List<List<RunRoutePoint>> pathSegments,
    required List<List<RunRoutePoint>> loopSegments,
  }) {
    final result = <Polyline>{};
    final seen = <String>{};
    var index = 0;

    void addSegments(List<List<RunRoutePoint>> segments, Color color) {
      for (final segment in segments) {
        if (segment.length < 2) continue;
        final signature = segment
            .map(
              (p) =>
                  '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
            )
            .join('|');
        if (seen.contains(signature)) continue;
        seen.add(signature);
        result.add(
          Polyline(
            polylineId: PolylineId('result_route_${index++}'),
            points: segment
                .map((point) => point.latLng)
                .toList(growable: false),
            color: color,
            width: 5,
          ),
        );
      }
    }

    addSegments(routeSegments, AppColors.primary);
    addSegments(pathSegments, AppColors.primary);
    addSegments(loopSegments, AppColors.primary.withValues(alpha: 0.8));
    return result;
  }

  Set<Polygon> _buildLoopPolygons(List<List<RunRoutePoint>> loopSegments) {
    final result = <Polygon>{};
    var index = 0;
    for (final segment in loopSegments) {
      if (segment.length < 3) continue;
      final points = segment.map((p) => p.latLng).toList(growable: false);
      final first = points.first;
      final last = points.last;
      final isClosed =
          (first.latitude - last.latitude).abs() < 1e-7 &&
          (first.longitude - last.longitude).abs() < 1e-7;
      final polygonPoints = isClosed ? points : [...points, first];
      result.add(
        Polygon(
          polygonId: PolygonId('result_loop_${index++}'),
          points: polygonPoints,
          strokeWidth: 1,
          strokeColor: AppColors.primary.withValues(alpha: 0.45),
          fillColor: AppColors.primary.withValues(alpha: 0.15),
        ),
      );
    }
    return result;
  }

  Future<BitmapDescriptor> _createDotIcon(Color color) async {
    const double size = 60.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Running map marker style: white ring + colored inner circle.
    final outerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, outerPaint);

    final innerPaint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.5, innerPaint);

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  void _selectAltitudePoint(RunRoutePoint point) {
    setState(() {
      _selectedAltitudePoint = point;
    });
  }

  String _formatRelativeAltitudeLabel(double metres) {
    final rounded = metres.toStringAsFixed(0);
    return metres > 0 ? '+$rounded m' : '$rounded m';
  }

  bool _hasFiniteAltitude(List<List<RunRoutePoint>> segments) {
    for (final segment in segments) {
      for (final point in segment) {
        final altitude = point.altitude;
        if (altitude != null && altitude.isFinite) {
          return true;
        }
      }
    }
    return false;
  }

  List<RunRoutePoint> _collectAltitudeSamples(
    List<List<RunRoutePoint>> segments,
  ) {
    final samples = <RunRoutePoint>[];
    for (final segment in segments) {
      for (final point in segment) {
        final altitude = point.altitude;
        if (altitude != null && altitude.isFinite) {
          samples.add(point);
        }
      }
    }
    return samples;
  }

  double _positiveAltitudeGain(RunRoutePoint previous, RunRoutePoint current) {
    final previousAltitude = previous.altitude;
    final currentAltitude = current.altitude;
    if (previousAltitude == null ||
        currentAltitude == null ||
        !previousAltitude.isFinite ||
        !currentAltitude.isFinite) {
      return 0.0;
    }
    final delta = currentAltitude - previousAltitude;
    return delta > 0 ? delta : 0.0;
  }

  double _calculateAscentFromSegments(List<List<RunRoutePoint>> segments) {
    var totalAscent = 0.0;
    for (final segment in segments) {
      for (var i = 1; i < segment.length; i++) {
        totalAscent += _positiveAltitudeGain(segment[i - 1], segment[i]);
      }
    }
    return totalAscent;
  }

  List<List<RunRoutePoint>> _geometrySegments({
    required dynamic loopGeom,
    required dynamic pathGeom,
  }) {
    final pathSegments = _segmentsFromGeometry(pathGeom);
    if (pathSegments.isNotEmpty) {
      return pathSegments;
    }

    final loopSegments = _segmentsFromGeometry(loopGeom);
    if (loopSegments.isNotEmpty) {
      return loopSegments;
    }

    return const [];
  }

  List<List<RunRoutePoint>> _segmentsFromGeometry(dynamic geometry) {
    final geoJsonSegments = _segmentsFromGeoJsonGeometry(geometry);
    if (geoJsonSegments.isNotEmpty) {
      return geoJsonSegments;
    }

    final geometryText = _normalizedGeometry(geometry);
    if (geometryText == null) {
      return const [];
    }

    final upper = geometryText.toUpperCase();
    if (upper.startsWith('MULTILINESTRING')) {
      final body = geometryText.substring(
        geometryText.indexOf('((') + 2,
        geometryText.lastIndexOf('))'),
      );
      return body
          .split(RegExp(r'\)\s*,\s*\('))
          .map(_parseCoordinateSequence)
          .where((segment) => segment.length >= 2)
          .toList(growable: false);
    }

    if (upper.startsWith('LINESTRING')) {
      final body = geometryText.substring(
        geometryText.indexOf('(') + 1,
        geometryText.lastIndexOf(')'),
      );
      final segment = _parseCoordinateSequence(body);
      return segment.length >= 2 ? [segment] : const [];
    }

    if (upper.startsWith('POLYGON')) {
      final body = geometryText.substring(
        geometryText.indexOf('((') + 2,
        geometryText.lastIndexOf('))'),
      );
      final firstRing = body.split(RegExp(r'\)\s*,\s*\(')).first;
      final segment = _parseCoordinateSequence(firstRing);
      return segment.length >= 2 ? [segment] : const [];
    }

    return const [];
  }

  String? _normalizedGeometry(dynamic geometry) {
    if (geometry is Map && geometry['wkt'] != null) {
      return _normalizedGeometry(geometry['wkt']);
    }

    final text = geometry?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final sridSeparatorIndex = text.indexOf(';');
    if (text.toUpperCase().startsWith('SRID=') && sridSeparatorIndex != -1) {
      return text.substring(sridSeparatorIndex + 1).trim();
    }

    return text.trim();
  }

  List<RunRoutePoint> _parseCoordinateSequence(String text) {
    return text
        .split(RegExp(r'\s*,\s*'))
        .map((pair) {
          final values = pair.trim().split(RegExp(r'\s+'));
          if (values.length < 2) {
            return null;
          }
          final longitude = double.tryParse(values[0]);
          final latitude = double.tryParse(values[1]);
          final altitude = values.length >= 3
              ? double.tryParse(values[2])
              : null;
          if (latitude == null || longitude == null) {
            return null;
          }
          return RunRoutePoint(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
          );
        })
        .whereType<RunRoutePoint>()
        .toList(growable: false);
  }

  List<List<RunRoutePoint>> _segmentsFromGeoJsonGeometry(dynamic geometry) {
    if (geometry is! Map) {
      return const [];
    }

    final type = geometry['type']?.toString().toUpperCase();
    final coordinates = geometry['coordinates'];
    if (type == null || coordinates == null) {
      return const [];
    }

    if (type == 'LINESTRING' && coordinates is List) {
      final segment = _coordinateArrayToPoints(coordinates);
      return segment.length >= 2 ? [segment] : const [];
    }

    if (type == 'MULTILINESTRING' && coordinates is List) {
      return coordinates
          .whereType<List>()
          .map(_coordinateArrayToPoints)
          .where((segment) => segment.length >= 2)
          .toList(growable: false);
    }

    if (type == 'POLYGON' && coordinates is List && coordinates.isNotEmpty) {
      final firstRing = coordinates.first;
      if (firstRing is List) {
        final segment = _coordinateArrayToPoints(firstRing);
        return segment.length >= 2 ? [segment] : const [];
      }
    }

    return const [];
  }

  List<RunRoutePoint> _coordinateArrayToPoints(List coordinates) {
    return coordinates
        .whereType<List>()
        .map((pair) {
          if (pair.length < 2) {
            return null;
          }
          final longitude = (pair[0] as num?)?.toDouble();
          final latitude = (pair[1] as num?)?.toDouble();
          final altitude = pair.length >= 3
              ? (pair[2] as num?)?.toDouble()
              : null;
          if (latitude == null || longitude == null) {
            return null;
          }
          return RunRoutePoint(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
          );
        })
        .whereType<RunRoutePoint>()
        .toList(growable: false);
  }
}
