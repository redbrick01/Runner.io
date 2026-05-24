import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app_colors.dart';
import '../design/app_design.dart';
import '../services/point_history_service.dart';
import '../services/run_history_service.dart';
import '../services/user_profile_store.dart';
import 'run_result_page.dart';

class TerritoryDetailPage extends StatefulWidget {
  const TerritoryDetailPage({super.key});

  @override
  State<TerritoryDetailPage> createState() => _TerritoryDetailPageState();
}

class _TerritoryDetailPageState extends State<TerritoryDetailPage> {
  bool _isLoading = true;
  List<RunHistoryEntry> _runs = const [];
  List<dynamic> _pointHistory = const [];
  UserProfileSnapshot? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        RunHistoryService.instance.fetchRunHistory(limit: 200),
        PointHistoryService.instance.fetchPointHistory(limit: 300, offset: 0),
        UserProfileStore.instance.fetch(force: true),
      ]);
      if (!mounted) return;
      setState(() {
        _runs = (results[0] as List<RunHistoryEntry>);
        _pointHistory = List<dynamic>.from(results[1] as List<dynamic>);
        _profile = results[2] as UserProfileSnapshot?;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _runs = const [];
        _pointHistory = const [];
        _profile = UserProfileStore.instance.current;
        _isLoading = false;
      });
    }
  }

  bool _isTerritoryMaintainEvent(String eventType) {
    return eventType == 'territory_points' ||
        eventType == 'territory-point' ||
        eventType == 'territory_point';
  }

  DateTime _startOfWeek(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    final diff = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: diff));
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  double get _currentAreaM2 => _profile?.area ?? 0.0;

  double get _todayCapturedAreaM2 {
    final now = DateTime.now();
    return _runs.fold<double>(0.0, (sum, run) {
      final startedAt = run.startedAt?.toLocal();
      if (startedAt == null) return sum;
      if (startedAt.year != now.year ||
          startedAt.month != now.month ||
          startedAt.day != now.day) {
        return sum;
      }
      return sum + _asDouble(run.raw['area']);
    });
  }

  double get _weekCapturedAreaM2 {
    final now = DateTime.now();
    final weekStart = _startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _runs.fold<double>(0.0, (sum, run) {
      final startedAt = run.startedAt?.toLocal();
      if (startedAt == null) return sum;
      if (startedAt.isBefore(weekStart) || !startedAt.isBefore(weekEnd)) {
        return sum;
      }
      return sum + _asDouble(run.raw['area']);
    });
  }

  int get _maintainedDays {
    final days = <String>{};
    for (final item in _pointHistory) {
      if (item is! Map) continue;
      final eventType = (item['event_type'] ?? '').toString();
      if (!_isTerritoryMaintainEvent(eventType)) continue;
      final date = _parseDate(item['created_at']);
      if (date == null) continue;
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      days.add(key);
    }
    return days.length;
  }

  double get _recent7DaysMaintainRate {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final days = <String>{};
    for (final item in _pointHistory) {
      if (item is! Map) continue;
      final eventType = (item['event_type'] ?? '').toString();
      if (!_isTerritoryMaintainEvent(eventType)) continue;
      final date = _parseDate(item['created_at']);
      if (date == null) continue;
      final dayOnly = DateTime(date.year, date.month, date.day);
      if (dayOnly.isBefore(start) || dayOnly.isAfter(now)) continue;
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      days.add(key);
    }
    return (days.length / 7.0) * 100;
  }

  String _formatArea(double areaM2) {
    final km2 = areaM2 / 1000000;
    if (km2 <= 0) return '0.00 km²';
    return '${km2.toStringAsFixed(km2 >= 10 ? 1 : 2)} km²';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}.$m.$d $h:$min';
  }

  List<RunHistoryEntry> get _topContributors {
    final copied = [..._runs];
    copied.sort(
      (a, b) => _asDouble(b.raw['area']).compareTo(_asDouble(a.raw['area'])),
    );
    return copied
        .where((run) => _asDouble(run.raw['area']) > 0)
        .take(5)
        .toList();
  }

  List<_TimelineItem> get _timelineItems {
    final result = <_TimelineItem>[];
    for (final run in _runs.take(20)) {
      final area = _asDouble(run.raw['area']);
      if (area <= 0) continue;
      result.add(
        _TimelineItem(
          title: '러닝 점령',
          subtitle: _formatArea(area),
          date: run.startedAt?.toLocal(),
          color: AppColors.primary,
        ),
      );
    }
    for (final item in _pointHistory.take(60)) {
      if (item is! Map) continue;
      final eventType = (item['event_type'] ?? '').toString();
      if (!_isTerritoryMaintainEvent(eventType)) continue;
      final points = _asDouble(item['points_delta']);
      result.add(
        _TimelineItem(
          title: '영토 유지',
          subtitle: '+${points.toStringAsFixed(1)} P',
          date: _parseDate(item['created_at']),
          color: Colors.orangeAccent,
        ),
      );
    }
    result.sort((a, b) {
      final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return result.take(12).toList(growable: false);
  }

  List<LatLng> _pointsFromGeometry(dynamic geometry) {
    final geoJson = _pointsFromGeoJson(geometry);
    if (geoJson.length >= 2) return geoJson;

    final geometryText = _normalizedGeometry(geometry);
    if (geometryText == null) return const [];

    final upper = geometryText.toUpperCase();
    if (upper.startsWith('MULTILINESTRING')) {
      final body = geometryText.substring(
        geometryText.indexOf('((') + 2,
        geometryText.lastIndexOf('))'),
      );
      return body
          .split(RegExp(r'\)\s*,\s*\('))
          .expand(_parseCoordinateSequence)
          .toList(growable: false);
    }
    if (upper.startsWith('LINESTRING')) {
      final body = geometryText.substring(
        geometryText.indexOf('(') + 1,
        geometryText.lastIndexOf(')'),
      );
      return _parseCoordinateSequence(body);
    }
    if (upper.startsWith('POLYGON')) {
      final body = geometryText.substring(
        geometryText.indexOf('((') + 2,
        geometryText.lastIndexOf('))'),
      );
      final firstRing = body.split(RegExp(r'\)\s*,\s*\(')).first;
      return _parseCoordinateSequence(firstRing);
    }
    return const [];
  }

  List<LatLng> _pointsFromGeoJson(dynamic geometry) {
    if (geometry is! Map) return const [];
    final type = geometry['type']?.toString().toUpperCase();
    final coordinates = geometry['coordinates'];
    if (type == null || coordinates == null) return const [];

    List<LatLng> toPoints(List values) {
      return values
          .whereType<List>()
          .map((pair) {
            if (pair.length < 2) return null;
            final lon = (pair[0] as num?)?.toDouble();
            final lat = (pair[1] as num?)?.toDouble();
            if (lon == null || lat == null) return null;
            return LatLng(lat, lon);
          })
          .whereType<LatLng>()
          .toList(growable: false);
    }

    if (type == 'LINESTRING' && coordinates is List) {
      return toPoints(coordinates);
    }
    if (type == 'MULTILINESTRING' && coordinates is List) {
      return coordinates
          .whereType<List>()
          .expand(toPoints)
          .toList(growable: false);
    }
    if (type == 'POLYGON' && coordinates is List && coordinates.isNotEmpty) {
      final firstRing = coordinates.first;
      if (firstRing is List) return toPoints(firstRing);
    }
    return const [];
  }

  String? _normalizedGeometry(dynamic geometry) {
    if (geometry is Map && geometry['wkt'] != null) {
      return _normalizedGeometry(geometry['wkt']);
    }
    final text = geometry?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final sridSeparatorIndex = text.indexOf(';');
    if (text.toUpperCase().startsWith('SRID=') && sridSeparatorIndex != -1) {
      return text.substring(sridSeparatorIndex + 1).trim();
    }
    return text.trim();
  }

  List<LatLng> _parseCoordinateSequence(String text) {
    return text
        .split(RegExp(r'\s*,\s*'))
        .map((pair) {
          final values = pair.trim().split(RegExp(r'\s+'));
          if (values.length < 2) return null;
          final lon = double.tryParse(values[0]);
          final lat = double.tryParse(values[1]);
          if (lon == null || lat == null) return null;
          return LatLng(lat, lon);
        })
        .whereType<LatLng>()
        .toList(growable: false);
  }

  _MapPreviewData? get _mapData {
    for (final run in _runs) {
      final raw = run.raw;
      final loop = _pointsFromGeometry(raw['loop_geom']);
      final path = _pointsFromGeometry(raw['path_geom']);
      if (loop.length >= 3 || path.length >= 2) {
        return _MapPreviewData(loop: loop, path: path);
      }
    }
    return null;
  }

  LatLng _centerOf(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(37.5665, 126.9780);
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  @override
  Widget build(BuildContext context) {
    final mapData = _mapData;
    final mapPoints = <LatLng>[...?mapData?.loop, ...?mapData?.path];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '점령면적 상세',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: AppSpacing.page,
                children: [
                  _MetricPanel(
                    currentArea: _formatArea(_currentAreaM2),
                    todayArea: _formatArea(_todayCapturedAreaM2),
                    weekArea: _formatArea(_weekCapturedAreaM2),
                    maintainedDays: _maintainedDays.toString(),
                    maintainRate:
                        '${_recent7DaysMaintainRate.toStringAsFixed(0)}%',
                    lastUpdated: _formatDateTime(
                      _runs.isNotEmpty ? _runs.first.startedAt : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppSurface(
                    height: 220,
                    padding: EdgeInsets.zero,
                    radius: 20,
                    clipBehavior: Clip.antiAlias,
                    child: mapPoints.length < 2
                        ? const Center(
                            child: Text(
                              '표시할 경로/영토 데이터가 없습니다.',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          )
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _centerOf(mapPoints),
                              zoom: 15,
                            ),
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            scrollGesturesEnabled: false,
                            zoomGesturesEnabled: false,
                            polygons: mapData!.loop.length >= 3
                                ? {
                                    Polygon(
                                      polygonId: const PolygonId('territory'),
                                      points: mapData.loop,
                                      fillColor: AppColors.primary.withValues(
                                        alpha: 0.18,
                                      ),
                                      strokeWidth: 2,
                                      strokeColor: AppColors.primary,
                                    ),
                                  }
                                : const {},
                            polylines: {
                              if (mapData.path.length >= 2)
                                Polyline(
                                  polylineId: const PolylineId('path'),
                                  points: mapData.path,
                                  width: 4,
                                  color: AppColors.primary,
                                ),
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '영토 점령 러닝',
                    child: _topContributors.isEmpty
                        ? const _EmptyText('기여 러닝 데이터가 없습니다.')
                        : Column(
                            children: _topContributors
                                .map(
                                  (run) => _ContributorTile(
                                    areaText: _formatArea(
                                      _asDouble(run.raw['area']),
                                    ),
                                    distanceText:
                                        '${(run.distanceMetres / 1000).toStringAsFixed(2)} km',
                                    dateText: _formatDateTime(run.startedAt),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              RunResultPage(runData: run.raw),
                                        ),
                                      );
                                    },
                                  ),
                                )
                                .toList(growable: false),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '변화 타임라인',
                    child: _timelineItems.isEmpty
                        ? const _EmptyText('표시할 이벤트가 없습니다.')
                        : Column(
                            children: _timelineItems
                                .map(
                                  (item) => _TimelineTile(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    dateText: _formatDateTime(item.date),
                                    color: item.color,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MapPreviewData {
  const _MapPreviewData({required this.loop, required this.path});

  final List<LatLng> loop;
  final List<LatLng> path;
}

class _TimelineItem {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.color,
  });

  final String title;
  final String subtitle;
  final DateTime? date;
  final Color color;
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.currentArea,
    required this.todayArea,
    required this.weekArea,
    required this.maintainedDays,
    required this.maintainRate,
    required this.lastUpdated,
  });

  final String currentArea;
  final String todayArea;
  final String weekArea;
  final String maintainedDays;
  final String maintainRate;
  final String lastUpdated;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCell(label: '현재 점령 면적', value: currentArea),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCell(label: '오늘 증가', value: todayArea),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricCell(label: '주간 증가', value: weekArea),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCell(label: '유지 일수', value: '$maintainedDays일'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricCell(label: '최근 7일 유지율', value: maintainRate),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCell(label: '마지막 갱신', value: lastUpdated),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: AppColors.surfaceSoft,
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ContributorTile extends StatelessWidget {
  const _ContributorTile({
    required this.areaText,
    required this.distanceText,
    required this.dateText,
    required this.onTap,
  });

  final String areaText;
  final String distanceText;
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AppSurface(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            color: AppColors.surfaceSoft,
            radius: 12,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.directions_run_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$distanceText  |  $dateText',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  areaText,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.title,
    required this.subtitle,
    required this.dateText,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String dateText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        color: AppColors.surfaceSoft,
        radius: 12,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    dateText,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: AppColors.secondaryText)),
    );
  }
}
