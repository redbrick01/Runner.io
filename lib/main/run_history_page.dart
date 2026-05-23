import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app_colors.dart';
import '../services/run_history_service.dart';
import 'running_map_page.dart';
import 'run_result_page.dart';

enum _HistoryRangeType { day, week, month, year, all }

class RunHistoryPage extends StatefulWidget {
  const RunHistoryPage({super.key});

  @override
  State<RunHistoryPage> createState() => _RunHistoryPageState();
}

class _RunHistoryPageState extends State<RunHistoryPage> {
  List<RunHistoryEntry> _entries = const [];
  bool _isLoading = true;
  _HistoryRangeType _rangeType = _HistoryRangeType.day;
  DateTime _anchorDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final entries = await RunHistoryService.instance.fetchRunHistory();
      if (!mounted) return;
      final latest = entries.isNotEmpty
          ? entries.first.startedAt?.toLocal()
          : null;
      setState(() {
        _entries = entries;
        if (latest != null) {
          _anchorDate = DateTime(latest.year, latest.month, latest.day);
        }
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('러닝 기록 로드 실패: $error');
      if (!mounted) return;
      setState(() {
        _entries = const [];
        _isLoading = false;
      });
    }
  }

  String _formatDistance(double metres) {
    final km = metres / 1000;
    return '${km.toStringAsFixed(km >= 10 ? 1 : 2)} km';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatPace(double secondsPerKm) {
    if (secondsPerKm <= 0) return "-'--\"";
    final minutes = secondsPerKm ~/ 60;
    final seconds = (secondsPerKm.round()) % 60;
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  String _formatAverageSpeed(double distanceMetres, int durationSeconds) {
    if (distanceMetres <= 0 || durationSeconds <= 0) return '-';
    final kmh = (distanceMetres / durationSeconds) * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  String _formatArea(double areaM2) {
    if (areaM2 <= 0) return '0 km²';
    final km2 = areaM2 / 1000000;
    return '${km2.toStringAsFixed(km2 >= 10 ? 1 : 2)} km²';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}.$mm.$dd $hh:$min';
  }

  DateTime _startOfWeek(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    final diff = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: diff));
  }

  List<RunHistoryEntry> _filteredEntries() {
    if (_rangeType == _HistoryRangeType.all) {
      return _entries;
    }

    return _entries
        .where((entry) {
          final startedAt = entry.startedAt?.toLocal();
          if (startedAt == null) return false;

          if (_rangeType == _HistoryRangeType.day) {
            return startedAt.year == _anchorDate.year &&
                startedAt.month == _anchorDate.month &&
                startedAt.day == _anchorDate.day;
          }
          if (_rangeType == _HistoryRangeType.week) {
            final weekStart = _startOfWeek(_anchorDate);
            final weekEnd = weekStart.add(const Duration(days: 7));
            return !startedAt.isBefore(weekStart) &&
                startedAt.isBefore(weekEnd);
          }
          if (_rangeType == _HistoryRangeType.month) {
            return startedAt.year == _anchorDate.year &&
                startedAt.month == _anchorDate.month;
          }
          if (_rangeType == _HistoryRangeType.year) {
            return startedAt.year == _anchorDate.year;
          }
          return true;
        })
        .toList(growable: false);
  }

  DateTime? _latestEntryDate({int? year, int? month}) {
    DateTime? latest;
    for (final entry in _entries) {
      final startedAt = entry.startedAt?.toLocal();
      if (startedAt == null) continue;
      if (year != null && startedAt.year != year) continue;
      if (month != null && startedAt.month != month) continue;
      if (latest == null || startedAt.isAfter(latest)) {
        latest = startedAt;
      }
    }
    return latest;
  }

  DateTime? _latestEntryInWeek(DateTime anchor) {
    final weekStart = _startOfWeek(anchor);
    final weekEnd = weekStart.add(const Duration(days: 7));
    DateTime? latest;
    for (final entry in _entries) {
      final startedAt = entry.startedAt?.toLocal();
      if (startedAt == null) continue;
      if (startedAt.isBefore(weekStart) || !startedAt.isBefore(weekEnd)) {
        continue;
      }
      if (latest == null || startedAt.isAfter(latest)) {
        latest = startedAt;
      }
    }
    return latest;
  }

  DateTime _normalizeAnchor(DateTime value, _HistoryRangeType type) {
    if (type == _HistoryRangeType.year) {
      return DateTime(value.year, 1, 1);
    }
    if (type == _HistoryRangeType.week) {
      return _startOfWeek(value);
    }
    if (type == _HistoryRangeType.month) {
      return DateTime(value.year, value.month, 1);
    }
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameAnchor(DateTime a, DateTime b, _HistoryRangeType type) {
    final na = _normalizeAnchor(a, type);
    final nb = _normalizeAnchor(b, type);
    return na.year == nb.year && na.month == nb.month && na.day == nb.day;
  }

  List<DateTime> _availableAnchors(_HistoryRangeType type) {
    if (type == _HistoryRangeType.all) return const [];
    final values = <DateTime>[];
    for (final entry in _entries) {
      final startedAt = entry.startedAt?.toLocal();
      if (startedAt == null) continue;
      values.add(_normalizeAnchor(startedAt, type));
    }
    values.sort((a, b) => a.compareTo(b));

    final unique = <DateTime>[];
    for (final value in values) {
      if (unique.isEmpty || !_isSameAnchor(unique.last, value, type)) {
        unique.add(value);
      }
    }
    return unique;
  }

  int _currentAnchorIndex(List<DateTime> anchors, _HistoryRangeType type) {
    final current = _normalizeAnchor(_anchorDate, type);
    for (var i = 0; i < anchors.length; i++) {
      if (_isSameAnchor(anchors[i], current, type)) {
        return i;
      }
    }
    return -1;
  }

  bool _canShift(int delta) {
    if (_rangeType == _HistoryRangeType.all) return false;
    final anchors = _availableAnchors(_rangeType);
    if (anchors.isEmpty) return false;

    final currentIndex = _currentAnchorIndex(anchors, _rangeType);
    if (currentIndex == -1) {
      if (delta > 0) {
        return anchors.any(
          (d) => d.isAfter(_normalizeAnchor(_anchorDate, _rangeType)),
        );
      }
      return anchors.any(
        (d) => d.isBefore(_normalizeAnchor(_anchorDate, _rangeType)),
      );
    }

    final nextIndex = currentIndex + (delta > 0 ? 1 : -1);
    return nextIndex >= 0 && nextIndex < anchors.length;
  }

  String _rangeLabel() {
    if (_rangeType == _HistoryRangeType.all) return '전체 기간';

    final y = _anchorDate.year.toString();
    final m = _anchorDate.month.toString().padLeft(2, '0');
    final d = _anchorDate.day.toString().padLeft(2, '0');
    if (_rangeType == _HistoryRangeType.day) return '$y.$m.$d';
    if (_rangeType == _HistoryRangeType.week) {
      final start = _startOfWeek(_anchorDate);
      final end = start.add(const Duration(days: 6));
      final startM = start.month.toString().padLeft(2, '0');
      final startD = start.day.toString().padLeft(2, '0');
      final endM = end.month.toString().padLeft(2, '0');
      final endD = end.day.toString().padLeft(2, '0');
      return '${start.year}.$startM.$startD ~ $endM.$endD';
    }
    if (_rangeType == _HistoryRangeType.month) return '$y.$m';
    return y;
  }

  void _shiftRange(int delta) {
    if (_rangeType == _HistoryRangeType.all) return;
    final anchors = _availableAnchors(_rangeType);
    if (anchors.isEmpty) return;

    final currentIndex = _currentAnchorIndex(anchors, _rangeType);
    int nextIndex;
    if (currentIndex == -1) {
      if (delta > 0) {
        nextIndex = anchors.indexWhere(
          (d) => d.isAfter(_normalizeAnchor(_anchorDate, _rangeType)),
        );
      } else {
        nextIndex = anchors.lastIndexWhere(
          (d) => d.isBefore(_normalizeAnchor(_anchorDate, _rangeType)),
        );
      }
    } else {
      nextIndex = currentIndex + (delta > 0 ? 1 : -1);
    }
    if (nextIndex < 0 || nextIndex >= anchors.length) return;

    setState(() {
      _anchorDate = anchors[nextIndex];
    });
  }

  void _onRangeTypeChanged(_HistoryRangeType nextType) {
    if (_rangeType == nextType) return;
    final previousType = _rangeType;
    setState(() {
      _rangeType = nextType;
      if (nextType == _HistoryRangeType.year) {
        _anchorDate = DateTime(_anchorDate.year, 1, 1);
      } else if (nextType == _HistoryRangeType.week) {
        final candidate =
            _latestEntryDate(year: _anchorDate.year) ?? _latestEntryDate();
        if (candidate != null) {
          _anchorDate = _startOfWeek(candidate);
        } else {
          _anchorDate = _startOfWeek(_anchorDate);
        }
      } else if (nextType == _HistoryRangeType.month) {
        final candidate =
            _latestEntryDate(year: _anchorDate.year) ?? _latestEntryDate();
        if (candidate != null) {
          _anchorDate = DateTime(candidate.year, candidate.month, 1);
        } else {
          _anchorDate = DateTime(_anchorDate.year, _anchorDate.month, 1);
        }
      } else if (nextType == _HistoryRangeType.day) {
        final candidate = previousType == _HistoryRangeType.week
            ? (_latestEntryInWeek(_anchorDate) ??
                  _latestEntryDate(year: _anchorDate.year) ??
                  _latestEntryDate())
            : (_latestEntryDate(
                    year: _anchorDate.year,
                    month: _anchorDate.month,
                  ) ??
                  _latestEntryDate(year: _anchorDate.year) ??
                  _latestEntryDate());
        if (candidate != null) {
          _anchorDate = DateTime(
            candidate.year,
            candidate.month,
            candidate.day,
          );
        } else {
          _anchorDate = DateTime(
            _anchorDate.year,
            _anchorDate.month,
            _anchorDate.day,
          );
        }
      } else if (nextType == _HistoryRangeType.all) {
        // keep current anchor for when user switches back from all
      }
    });
  }

  Widget _buildRangeToggleBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _RangeTab(
            label: '일',
            selected: _rangeType == _HistoryRangeType.day,
            onTap: () => _onRangeTypeChanged(_HistoryRangeType.day),
          ),
          _RangeTab(
            label: '주',
            selected: _rangeType == _HistoryRangeType.week,
            onTap: () => _onRangeTypeChanged(_HistoryRangeType.week),
          ),
          _RangeTab(
            label: '월',
            selected: _rangeType == _HistoryRangeType.month,
            onTap: () => _onRangeTypeChanged(_HistoryRangeType.month),
          ),
          _RangeTab(
            label: '년',
            selected: _rangeType == _HistoryRangeType.year,
            onTap: () => _onRangeTypeChanged(_HistoryRangeType.year),
          ),
          _RangeTab(
            label: '전체',
            selected: _rangeType == _HistoryRangeType.all,
            onTap: () => _onRangeTypeChanged(_HistoryRangeType.all),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.text,
            onPressed: _canShift(-1) ? () => _shiftRange(-1) : null,
          ),
          Expanded(
            child: Text(
              _rangeLabel(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.text,
            onPressed: _canShift(1) ? () => _shiftRange(1) : null,
          ),
        ],
      ),
    );
  }

  List<LatLng> _previewPoints(Map<String, dynamic> raw) {
    final pathPoints = _pointsFromGeometry(raw['path_geom']);
    if (pathPoints.length >= 2) {
      return pathPoints;
    }
    return const [];
  }

  List<LatLng> _pointsFromGeometry(dynamic geometry) {
    final geoJson = _pointsFromGeoJson(geometry);
    if (geoJson.length >= 2) {
      return geoJson;
    }

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
            final longitude = (pair[0] as num?)?.toDouble();
            final latitude = (pair[1] as num?)?.toDouble();
            if (longitude == null || latitude == null) return null;
            return LatLng(latitude, longitude);
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
      if (firstRing is List) {
        return toPoints(firstRing);
      }
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
          final longitude = double.tryParse(values[0]);
          final latitude = double.tryParse(values[1]);
          if (longitude == null || latitude == null) return null;
          return LatLng(latitude, longitude);
        })
        .whereType<LatLng>()
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = _filteredEntries();
    final totalDistance = visibleEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.distanceMetres,
    );
    final totalDuration = visibleEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.durationSeconds,
    );
    final totalPoint = visibleEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.point,
    );
    final totalAreaM2 = visibleEntries.fold<double>(
      0,
      (sum, entry) => sum + ((entry.raw['area'] as num?)?.toDouble() ?? 0.0),
    );
    final averageDistance = visibleEntries.isEmpty
        ? 0.0
        : totalDistance / visibleEntries.length;
    final averagePaceSecondsPerKm = totalDistance > 0
        ? totalDuration / (totalDistance / 1000)
        : 0.0;
    final summaryMetrics = <Map<String, String>>[
      {'label': '총 러닝', 'value': '${visibleEntries.length}회'},
      {'label': '평균 거리', 'value': _formatDistance(averageDistance)},
      {'label': '평균 페이스', 'value': _formatPace(averagePaceSecondsPerKm)},
      {'label': '총 거리', 'value': _formatDistance(totalDistance)},
      {'label': '총 시간', 'value': _formatDuration(totalDuration)},
      {'label': '총 획득 포인트', 'value': '${totalPoint.toStringAsFixed(0)} P'},
      {'label': '총 점령 넓이', 'value': _formatArea(totalAreaM2)},
    ];
    final summaryPages = <List<Map<String, String>>>[];
    for (var i = 0; i < summaryMetrics.length; i += 3) {
      final end = (i + 3 < summaryMetrics.length)
          ? i + 3
          : summaryMetrics.length;
      summaryPages.add(summaryMetrics.sublist(i, end));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '러닝 통계',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : visibleEntries.isEmpty
          ? const Center(
              child: Text(
                '러닝 기록이 없습니다.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < 200) return;
                  if (velocity < 0) {
                    _shiftRange(1);
                  } else {
                    _shiftRange(-1);
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _buildRangeToggleBar(),
                    const SizedBox(height: 10),
                    _buildRangeNavigator(),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SizedBox(
                        height: 54,
                        child: PageView.builder(
                          itemCount: summaryPages.length,
                          controller: PageController(viewportFraction: 1),
                          itemBuilder: (context, pageIndex) {
                            final pageMetrics = summaryPages[pageIndex];
                            return Row(
                              children: [
                                for (final metric in pageMetrics)
                                  Expanded(
                                    child: _SummaryMetric(
                                      label: metric['label']!,
                                      value: metric['value']!,
                                    ),
                                  ),
                                for (var i = pageMetrics.length; i < 3; i++)
                                  const Expanded(child: SizedBox.shrink()),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...visibleEntries.map((entry) {
                      final previewPoints = _previewPoints(entry.raw);
                      final areaM2 =
                          ((entry.raw['area'] as num?)?.toDouble() ?? 0.0);
                      const previewSize = 124.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RunResultPage(runData: entry.raw),
                              ),
                            );
                            if (!context.mounted || result is! Map) return;
                            if (result['action']?.toString() !=
                                'focus_territory') {
                              return;
                            }
                            final lat = (result['lat'] as num?)?.toDouble();
                            final lng = (result['lng'] as num?)?.toDouble();
                            if (lat == null || lng == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RunningMapPage(
                                  initialFocusTarget: LatLng(lat, lng),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: previewSize,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatDate(entry.startedAt),
                                              textAlign: TextAlign.left,
                                              style: const TextStyle(
                                                color: AppColors.secondaryText,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _formatDistance(
                                                        entry.distanceMetres,
                                                      ),
                                                      textAlign: TextAlign.left,
                                                      style: const TextStyle(
                                                        color: AppColors.text,
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      children: [
                                                        if (areaM2 > 0) ...[
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 6,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors
                                                                  .green
                                                                  .withValues(
                                                                    alpha: 0.10,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    999,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              _formatArea(
                                                                areaM2,
                                                              ),
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .green,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                        ],
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 6,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors
                                                                .primarySoft,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            '${entry.point.toStringAsFixed(2)} P',
                                                            style:
                                                                const TextStyle(
                                                                  color: AppColors
                                                                      .primary,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _RoutePreviewSquare(
                                      points: previewPoints,
                                      size: previewSize,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _HistoryMetric(
                                        label: '시간',
                                        value: _formatDuration(
                                          entry.durationSeconds,
                                        ),
                                        center: true,
                                      ),
                                    ),
                                    Expanded(
                                      child: _HistoryMetric(
                                        label: '평균 페이스',
                                        value: _formatPace(
                                          entry.avgPaceSecondsPerKm,
                                        ),
                                        center: true,
                                      ),
                                    ),
                                    Expanded(
                                      child: _HistoryMetric(
                                        label: '평균 속도',
                                        value: _formatAverageSpeed(
                                          entry.distanceMetres,
                                          entry.durationSeconds,
                                        ),
                                        center: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RangeTab extends StatelessWidget {
  const _RangeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({
    required this.label,
    required this.value,
    this.center = false,
  });

  final String label;
  final String value;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
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
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RoutePreviewSquare extends StatelessWidget {
  const _RoutePreviewSquare({required this.points, this.size = 96});

  final List<LatLng> points;
  final double size;

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: points.length < 2
              ? const Center(
                  child: Icon(
                    Icons.route_outlined,
                    size: 20,
                    color: AppColors.secondaryText,
                  ),
                )
              : GoogleMap(
                  key: ValueKey(
                    'history_preview_${points.first.latitude}_${points.first.longitude}_${points.length}',
                  ),
                  initialCameraPosition: CameraPosition(
                    target: points.first,
                    zoom: 15,
                  ),
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('preview_route'),
                      points: points,
                      color: AppColors.primary,
                      width: 4,
                    ),
                  },
                  onMapCreated: (controller) async {
                    try {
                      await controller.moveCamera(
                        CameraUpdate.newLatLngBounds(
                          _boundsFromPoints(points),
                          8,
                        ),
                      );
                    } catch (_) {}
                  },
                  liteModeEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                ),
        ),
      ),
    );
  }
}
