import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../app_colors.dart';
import '../design/app_design.dart';
import '../services/run_service.dart';
import '../services/running_map_service.dart';
import 'ranking_page.dart';
import 'point_history_page.dart';
import 'my_page.dart';
import 'run_history_page.dart';
import 'run_session_engine.dart';
import 'run_result_page.dart';
import 'statistics_page.dart';
import 'territory_detail_page.dart';

class RunningMapPage extends StatefulWidget {
  final LatLng? initialFocusTarget;
  final double initialFocusZoom;

  const RunningMapPage({
    super.key,
    this.initialFocusTarget,
    this.initialFocusZoom = 16.5,
  });

  @override
  State<RunningMapPage> createState() => _RunningMapPageState();
}

class _RunningMapPageState extends State<RunningMapPage>
    with WidgetsBindingObserver {
  static const MethodChannel _liveActivityChannel = MethodChannel(
    'run_live_activity',
  );
  static const double _maxAcceptedAccuracyMeters = 25;
  static const double _minMovementMeters = 3;
  static const double _maxDerivedSpeedMps = 30;
  static const int _warmupSampleCount = 2;

  GoogleMapController? mapController;
  LatLng? _currentPosition;
  bool _isLoading = true;
  late final RunSessionEngine _session;

  // 러닝 상태 및 데이터 변수
  bool _isFinishingRun = false;
  bool _isFollowingUser = false;
  bool _isAppInForeground = true;
  bool _hasAutoCenteredInitially = false;
  bool _hasUserInteractedWithMap = false;
  bool _isProgrammaticCameraMove = false;
  double _currentZoom = 16;
  double _currentBearing = 0;
  LatLng? _currentCameraTarget;
  static const double _runningFollowZoom = 18;
  static const double _manualLocateZoom = 18;
  static const double _compassResetThreshold = 1;
  String? _currentUserId;

  Timer? _timer;
  Timer? _territoryTimer;
  Timer? _countdownTimer;
  int _countdownValue = 3;
  DateTime? _countdownEndAt;
  bool _countdownIsResuming = false;

  // 점령, 랭킹, 포인트 데이터
  double _occupiedArea = 0.0;
  double _points = 0.0;
  double? _weightKg;
  int _ranking = 0;
  String _userColorHex = "#448AFF"; // 기본 컬러

  StreamSubscription<Position>? _positionStream;
  List<RunRoutePoint> _withResolvedAltitude(List<RunRoutePoint> points) {
    if (points.isEmpty) {
      return points;
    }

    final resolved = List<RunRoutePoint>.from(points);
    double? lastKnownAltitude;
    for (var i = 0; i < resolved.length; i++) {
      final altitude = resolved[i].altitude;
      if (altitude != null && altitude.isFinite) {
        lastKnownAltitude = altitude;
        continue;
      }
      if (lastKnownAltitude != null) {
        resolved[i] = resolved[i].copyWith(altitude: lastKnownAltitude);
      }
    }

    double? nextKnownAltitude;
    for (var i = resolved.length - 1; i >= 0; i--) {
      final altitude = resolved[i].altitude;
      if (altitude != null && altitude.isFinite) {
        nextKnownAltitude = altitude;
        continue;
      }
      resolved[i] = resolved[i].copyWith(altitude: nextKnownAltitude ?? 0.0);
    }

    return resolved;
  }

  double _safePositiveAltitudeDelta(
    RunRoutePoint previous,
    RunRoutePoint current,
  ) {
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

  double _estimateMetFromSpeed(double avgSpeedKmH) {
    if (avgSpeedKmH < 4.0) return 2.5;
    if (avgSpeedKmH < 6.0) return 4.3;
    if (avgSpeedKmH < 8.0) return 8.3;
    if (avgSpeedKmH < 9.7) return 9.0;
    if (avgSpeedKmH < 10.8) return 9.8;
    if (avgSpeedKmH < 11.3) return 10.5;
    if (avgSpeedKmH < 12.1) return 11.0;
    if (avgSpeedKmH < 12.9) return 11.5;
    if (avgSpeedKmH < 13.8) return 11.8;
    if (avgSpeedKmH < 14.5) return 12.3;
    if (avgSpeedKmH < 16.1) return 12.8;
    if (avgSpeedKmH < 17.5) return 14.5;
    if (avgSpeedKmH < 19.3) return 16.0;
    if (avgSpeedKmH < 20.9) return 19.0;
    return 19.8;
  }

  double? _estimateCalories({
    required double distanceKm,
    required double durationHours,
    required double avgSpeedKmH,
    required double? weightKg,
  }) {
    if (weightKg == null || !weightKg.isFinite || weightKg <= 0) {
      return null;
    }
    if (distanceKm <= 0 || durationHours <= 0) {
      return 0.0;
    }
    final met = _estimateMetFromSpeed(avgSpeedKmH);
    final calories = met * weightKg * durationHours;
    if (!calories.isFinite || calories < 0) {
      return null;
    }
    return double.parse(calories.toStringAsFixed(1));
  }

  List<Map<String, dynamic>> _buildRunSplits({
    required List<RunRoutePoint> routePoints,
    required int totalDurationSeconds,
    double? totalCalories,
  }) {
    const splitDistanceMeters = 1000.0;
    final segments = splitRoutePointSegments(routePoints);
    if (segments.isEmpty) {
      return const [];
    }

    final splits = <Map<String, dynamic>>[];
    var currentDistance = 0.0;
    var currentAscent = 0.0;
    var currentDuration = 0.0;
    var splitIndex = 1;

    void finalizeSplit(
      double distanceMeters,
      double ascentMeters,
      double durationSeconds,
    ) {
      if (distanceMeters <= 0) {
        return;
      }
      splits.add({
        'split_index': splitIndex,
        'distance_m': distanceMeters,
        'ascent_m': ascentMeters,
        'duration_s_raw': durationSeconds,
      });
      splitIndex++;
    }

    for (final segment in segments) {
      for (var i = 1; i < segment.length; i++) {
        final previous = segment[i - 1];
        final current = segment[i];
        var segmentDistance = Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          current.latitude,
          current.longitude,
        );
        if (!segmentDistance.isFinite || segmentDistance <= 0) {
          continue;
        }

        final segmentDuration = _segmentDurationSeconds(previous, current);
        var segmentAscent = _safePositiveAltitudeDelta(previous, current);
        var segmentDurationRemaining = segmentDuration ?? 0.0;
        while (segmentDistance > 0) {
          final remainingForSplit = splitDistanceMeters - currentDistance;
          final chunkDistance = math.min(segmentDistance, remainingForSplit);
          final ratio = chunkDistance / segmentDistance;
          final chunkAscent = segmentAscent * ratio;
          final chunkDuration = segmentDuration == null
              ? 0.0
              : segmentDurationRemaining * ratio;

          currentDistance += chunkDistance;
          currentAscent += chunkAscent;
          currentDuration += chunkDuration;
          segmentDistance -= chunkDistance;
          segmentAscent -= chunkAscent;
          segmentDurationRemaining -= chunkDuration;

          if (currentDistance >= splitDistanceMeters - 0.001) {
            finalizeSplit(currentDistance, currentAscent, currentDuration);
            currentDistance = 0.0;
            currentAscent = 0.0;
            currentDuration = 0.0;
          }
        }
      }
    }

    if (currentDistance > 0.001) {
      finalizeSplit(currentDistance, currentAscent, currentDuration);
    }

    if (splits.isEmpty) {
      return const [];
    }

    final totalDistance = splits.fold<double>(
      0.0,
      (sum, split) => sum + ((split['distance_m'] as num).toDouble()),
    );
    if (totalDistance <= 0) {
      return const [];
    }

    final targetDurationSeconds = totalDurationSeconds.toDouble();
    final measuredDurationSum = splits.fold<double>(0.0, (sum, split) {
      final raw = (split['duration_s_raw'] as num?)?.toDouble() ?? 0.0;
      return raw > 0 ? sum + raw : sum;
    });
    final unmeasuredDistance = splits.fold<double>(0.0, (sum, split) {
      final raw = (split['duration_s_raw'] as num?)?.toDouble() ?? 0.0;
      if (raw > 0) return sum;
      final distance = (split['distance_m'] as num?)?.toDouble() ?? 0.0;
      return distance > 0 ? sum + distance : sum;
    });
    final remainingDurationBudget = math.max(
      0.0,
      targetDurationSeconds - measuredDurationSum,
    );

    return splits
        .map((split) {
          final distance = (split['distance_m'] as num).toDouble();
          final ascent = (split['ascent_m'] as num).toDouble();
          final rawDuration =
              (split['duration_s_raw'] as num?)?.toDouble() ?? 0.0;
          final duration = rawDuration > 0
              ? rawDuration
              : (unmeasuredDistance > 0
                    ? remainingDurationBudget * (distance / unmeasuredDistance)
                    : 0.0);
          final avgPace = distance > 0 ? duration / (distance / 1000) : 0.0;
          final avgSpeed = duration > 0 ? distance / duration : 0.0;
          final splitCalories = (totalCalories != null && totalCalories > 0)
              ? totalCalories * (distance / totalDistance)
              : null;

          return {
            'split_index': split['split_index'],
            'distance_m': double.parse(distance.toStringAsFixed(2)),
            'duration_s': double.parse(duration.toStringAsFixed(2)),
            'avg_pace_s_per_km': double.parse(avgPace.toStringAsFixed(2)),
            'avg_speed_mps': double.parse(avgSpeed.toStringAsFixed(3)),
            'ascent_m': double.parse(ascent.toStringAsFixed(2)),
            'calories': splitCalories == null
                ? null
                : double.parse(splitCalories.toStringAsFixed(1)),
          };
        })
        .toList(growable: false);
  }

  double? _segmentDurationSeconds(
    RunRoutePoint previous,
    RunRoutePoint current,
  ) {
    final previousTimestamp = previous.timestampMillis;
    final currentTimestamp = current.timestampMillis;
    if (previousTimestamp == null || currentTimestamp == null) {
      return null;
    }
    final elapsedSeconds = (currentTimestamp - previousTimestamp) / 1000.0;
    if (!elapsedSeconds.isFinite || elapsedSeconds <= 0) {
      return null;
    }
    return elapsedSeconds;
  }

  double _totalSplitDistanceMeters(List<Map<String, dynamic>> splits) {
    if (splits.isEmpty) return 0.0;
    return splits.fold<double>(0.0, (sum, split) {
      final distance = (split['distance_m'] as num?)?.toDouble() ?? 0.0;
      if (!distance.isFinite || distance <= 0) {
        return sum;
      }
      return sum + distance;
    });
  }

  double _distanceFromRouteSamples(List<RunRoutePoint> points) {
    if (points.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      final current = points[i];
      if (current.startsNewSegment) {
        continue;
      }
      final previous = points[i - 1];
      final segmentDistance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
      if (!segmentDistance.isFinite || segmentDistance <= 0) {
        continue;
      }
      total += segmentDistance;
    }
    return total;
  }

  String _pathGeomWithAltitude(List<List<RunRoutePoint>> routeSegments) {
    final resolvedSegments = routeSegments
        .map(_withResolvedAltitude)
        .where((segment) => segment.length >= 2)
        .toList(growable: false);

    if (resolvedSegments.isEmpty) {
      return '';
    }

    if (resolvedSegments.length == 1) {
      final segment = resolvedSegments.first;
      return 'LINESTRING Z(${segment.map((p) => "${p.longitude} ${p.latitude} ${p.altitude ?? 0.0}").join(", ")})';
    }

    return 'MULTILINESTRING Z(${resolvedSegments.map((segment) => "(${segment.map((p) => "${p.longitude} ${p.latitude} ${p.altitude ?? 0.0}").join(", ")})").join(", ")})';
  }

  // API 최적화 변수
  DateTime? _lastFetchTime;
  DateTime? _lastUserRankingFetchTime;
  bool _isFetchingTerritory = false;
  Future<void>? _userRankingFetchFuture;
  bool _isCountdownActive = false;

  // 실시간 경로 및 영토 데이터
  final Set<Polyline> _polylines = {};
  final Set<Polygon> _territoryPolygons = {};
  final Set<Marker> _territoryMarkers = {};
  final Map<String, LatLngBounds> _territoryMarkerBounds = {};
  final Map<String, BitmapDescriptor> _nicknameCache = {};
  BitmapDescriptor? _currentLocationIcon;
  final FlutterTts _splitTts = FlutterTts();
  bool _isSplitTtsConfigured = false;
  int _lastAnnouncedSplitKm = 0;
  int _lastAnnouncedSplitElapsedSeconds = 0;
  bool _iosCountdownBackgroundTaskActive = false;

  // 구글 지도 커스텀 스타일 (POI 아이콘 제거됨)
  final String _mapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#f5f5f5"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#f5f5f5"}]},
  {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#eeeeee"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#e5e5e5"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
  {"featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#dadada"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "transit.line", "elementType": "geometry", "stylers": [{"color": "#e5e5e5"}]},
  {"featureType": "transit.station", "elementType": "geometry", "stylers": [{"color": "#eeeeee"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#c9c9c9"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]}
]
''';

  bool get _isStarted => _session.isStarted;
  bool get _isPaused => _session.isPaused;
  DateTime? get _startTime => _session.startTime;
  int get _seconds => _session.elapsedSeconds;
  double get _totalDistance => _session.totalDistance;
  double get _currentSpeed => _session.currentSpeed;
  double get _totalAscent => _session.totalAscent;
  String? get _currentRunId => _session.currentRunId;
  List<RunRoutePoint> get _routePointSamples => _session.routePoints;
  List<LatLng> get _routePoints =>
      _routePointSamples.map((point) => point.latLng).toList(growable: false);
  List<List<RunRoutePoint>> get _routeSegments =>
      splitRoutePointSegments(_routePointSamples);

  @override
  void initState() {
    super.initState();
    _session = RunSessionEngine(
      maxAcceptedAccuracyMeters: _maxAcceptedAccuracyMeters,
      minMovementMeters: _minMovementMeters,
      maxDerivedSpeedMps: _maxDerivedSpeedMps,
      warmupSampleCount: _warmupSampleCount,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_updateCurrentLocationIcon());
    unawaited(_fetchUserRanking());
    _startTerritoryUpdates();
    unawaited(_initializeLocationTracking());
    unawaited(() async {
      if (Platform.isAndroid) {
        await _restoreAndroidBackgroundSnapshot();
      }
    }());
    _consumePendingLiveActivityAction();
    unawaited(_configureSplitTts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveActivityChannel.setMethodCallHandler(null);
    _timer?.cancel();
    _territoryTimer?.cancel();
    _countdownTimer?.cancel();
    _positionStream?.cancel();
    _splitTts.stop();
    unawaited(_endIosCountdownBackgroundTask());
    super.dispose();
  }

  Future<void> _beginIosCountdownBackgroundTask() async {
    if (!Platform.isIOS || _iosCountdownBackgroundTaskActive) return;
    try {
      await _liveActivityChannel.invokeMethod<void>(
        'beginCountdownBackgroundTask',
      );
      _iosCountdownBackgroundTaskActive = true;
    } catch (e) {
      debugPrint('iOS countdown background task start failed: $e');
    }
  }

  Future<void> _endIosCountdownBackgroundTask() async {
    if (!Platform.isIOS || !_iosCountdownBackgroundTaskActive) return;
    try {
      await _liveActivityChannel.invokeMethod<void>(
        'endCountdownBackgroundTask',
      );
    } catch (e) {
      debugPrint('iOS countdown background task end failed: $e');
    } finally {
      _iosCountdownBackgroundTaskActive = false;
    }
  }

  Future<void> _configureSplitTts() async {
    if (_isSplitTtsConfigured) return;
    try {
      if (Platform.isIOS) {
        await _splitTts.setSharedInstance(true);
        await _splitTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          const [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } else if (Platform.isAndroid) {
        await _splitTts.setAudioAttributesForNavigation();
      }
      await _splitTts.setLanguage('ko-KR');
      await _splitTts.setSpeechRate(0.48);
      await _splitTts.setPitch(1.0);
      await _splitTts.awaitSpeakCompletion(false);
      _isSplitTtsConfigured = true;
    } catch (e) {
      debugPrint('Split TTS configure failed: $e');
    }
  }

  String _formatSplitPaceKorean(double secondsPerKm) {
    if (!secondsPerKm.isFinite || secondsPerKm <= 0) {
      return '측정 불가';
    }
    final totalSeconds = secondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes분 ${seconds.toString().padLeft(2, '0')}초';
  }

  Future<void> _playSplitChime() async {
    try {
      await _liveActivityChannel.invokeMethod<void>('playSplitChime');
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (e) {
        debugPrint('Split chime play failed: $e');
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  Future<void> _playRunStartEffect() async {
    try {
      await _liveActivityChannel.invokeMethod<void>('playSplitChime');
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  Future<void> _announceSplitIfNeeded() async {
    if (!_isStarted || _isPaused) return;
    final completedKm = (_totalDistance / 1000).floor();
    if (completedKm <= _lastAnnouncedSplitKm) return;

    final elapsedNow = _seconds;
    final splitDuration = elapsedNow - _lastAnnouncedSplitElapsedSeconds;
    final splitPaceSeconds = splitDuration > 0 ? splitDuration.toDouble() : 0.0;
    final splitPaceText = _formatSplitPaceKorean(splitPaceSeconds);
    final speech = '$completedKm킬로미터, 구간 페이스 $splitPaceText';

    _lastAnnouncedSplitKm = completedKm;
    _lastAnnouncedSplitElapsedSeconds = elapsedNow;

    try {
      if (!_isAppInForeground) {
        if (Platform.isAndroid) {
          await _liveActivityChannel.invokeMethod<void>(
            'announceSplitInBackground',
            speech,
          );
          return;
        }
        if (Platform.isIOS) {
          await _liveActivityChannel.invokeMethod<void>(
            'announceSplitInBackground',
            {
              'speech': speech,
              'completedKm': completedKm,
              'elapsedSeconds': elapsedNow,
            },
          );
          return;
        }
      }
      await _configureSplitTts();
      await _playSplitChime();
      await _splitTts.stop();
      await _splitTts.speak(speech);
    } catch (e) {
      debugPrint('Split TTS speak failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      unawaited(_fetchUserRanking(force: true));
      if (Platform.isAndroid && _isStarted) {
        unawaited(() async {
          await _restoreAndroidBackgroundSnapshot();
          await _stopAndroidBackgroundTracking();
        }());
      } else if (!_isStarted) {
        unawaited(
          _initializeLocationTracking(
            restartTracking: true,
            forceTerritoryRefresh: true,
          ),
        );
      }
      _refreshRunningMetrics();
      _tickCountdown();
      if (_isStarted) {
        unawaited(_updateLiveActivity());
      }
      unawaited(_consumePendingLiveActivityAction());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_isStarted) {
        if (Platform.isAndroid) {
          unawaited(_startAndroidBackgroundTracking());
        }
      } else if (_isCountdownActive && Platform.isIOS) {
        _completeCountdown();
        _startLocationTracking(enableBackgroundUpdates: true);
      } else if (Platform.isIOS) {
        _positionStream?.cancel();
      }
    }
  }

  Future<void> _initializeLocationTracking({
    bool restartTracking = false,
    bool forceTerritoryRefresh = false,
  }) async {
    try {
      await _determinePosition();
      if (!mounted) {
        return;
      }
      if (restartTracking || _positionStream == null) {
        _startLocationTracking(enableBackgroundUpdates: false);
      }
      if (_currentPosition != null) {
        unawaited(_fetchTerritories(force: forceTerritoryRefresh));
      }
    } catch (e) {
      debugPrint('위치 추적 초기화 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startAndroidBackgroundTracking() async {
    if (!Platform.isAndroid || !_isStarted || _currentRunId == null) {
      return;
    }

    try {
      await _liveActivityChannel
          .invokeMethod<void>('startAndroidBackgroundTracking', {
            'runId': _currentRunId,
            'title': '러닝 중',
            'elapsedSeconds': _seconds,
            'distanceMeters': _totalDistance,
            'totalAscentMeters': _totalAscent,
            'paceText': _calculatePace(),
            'isPaused': _isPaused,
            'routePointsJson': jsonEncode(
              _routePointSamples.map((point) => point.toJson()).toList(),
            ),
          });
    } catch (e) {
      debugPrint('Android background tracking start failed: $e');
    }
  }

  Future<void> _stopAndroidBackgroundTracking() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _liveActivityChannel.invokeMethod<void>(
        'stopAndroidBackgroundTracking',
      );
    } catch (e) {
      debugPrint('Android background tracking stop failed: $e');
    }
  }

  Future<void> _restoreAndroidBackgroundSnapshot() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final result = await _liveActivityChannel.invokeMethod<dynamic>(
        'getAndroidRunSnapshot',
      );
      if (result is! Map) {
        return;
      }

      final snapshot = Map<String, dynamic>.from(result);
      final runId = snapshot['runId'] as String?;
      final startedAtMillis = (snapshot['startedAt'] as num?)?.toInt();
      if (runId == null || startedAtMillis == null || startedAtMillis <= 0) {
        return;
      }

      final routePointsRaw = (snapshot['routePoints'] as List? ?? const []);
      final routePoints = routePointsRaw
          .whereType<Map>()
          .map((point) => RunRoutePoint.fromJson(point))
          .toList();

      _session.restore(
        RunSessionSnapshot(
          runId: runId,
          startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMillis),
          isPaused: snapshot['isPaused'] as bool? ?? false,
          accumulatedPausedMillis:
              (snapshot['pausedDurationMillis'] as num?)?.toInt() ?? 0,
          totalDistance:
              (snapshot['distanceMeters'] as num?)?.toDouble() ?? 0.0,
          currentSpeed: 0.0,
          totalAscent:
              (snapshot['totalAscentMeters'] as num?)?.toDouble() ?? 0.0,
          routePoints: routePoints,
        ),
      );
      if (!mounted) {
        return;
      }
      _lastAnnouncedSplitKm = (_totalDistance / 1000).floor();
      _lastAnnouncedSplitElapsedSeconds = _seconds;
      setState(() {
        _polylines.clear();
        if (_routePoints.isNotEmpty) {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('running_route'),
              points: List.from(_routePoints),
              color: _colorFromHex(_userColorHex).withValues(alpha: 0.5),
              width: 8,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Android background snapshot restore failed: $e');
    }
  }

  void _ensureRunningTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isStarted) {
        timer.cancel();
        return;
      }
      if (!_isPaused) {
        _refreshRunningMetrics();
        unawaited(_updateLiveActivity());
      }
    });
  }

  void _refreshRunningMetrics() {
    if (!_isStarted || _startTime == null) {
      return;
    }

    if (!mounted || !_session.refreshElapsed()) {
      return;
    }

    setState(() {});
  }

  Future<void> _consumePendingLiveActivityAction() async {
    _liveActivityChannel.setMethodCallHandler((call) async {
      if (call.method != 'onLiveActivityAction') {
        return;
      }
      await _applyLiveActivityAction(
        Map<String, dynamic>.from(call.arguments as Map),
      );
    });

    try {
      final result = await _liveActivityChannel.invokeMethod<dynamic>(
        'consumePendingAction',
      );
      if (result is Map) {
        await _applyLiveActivityAction(Map<String, dynamic>.from(result));
      }
    } catch (e) {
      debugPrint('Live Activity action consume failed: $e');
    }
  }

  Future<void> _applyLiveActivityAction(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    final runId = payload['runId'] as String?;

    if (!_isStarted ||
        runId == null ||
        runId != _currentRunId ||
        action == null) {
      return;
    }

    switch (action) {
      case 'pause':
        if (!_isPaused) {
          _togglePause();
        }
        break;
      case 'resume':
        if (_isPaused) {
          _togglePause();
        }
        break;
      case 'stop':
        await _stopRunning();
        break;
      case 'cancel':
        await _cancelRunning(skipDialog: true);
        break;
    }

    try {
      await _liveActivityChannel.invokeMethod<void>('clearPendingAction');
    } catch (e) {
      debugPrint('Live Activity action clear failed: $e');
    }
  }

  Future<void> _startLiveActivity() async {
    if (_currentRunId == null) return;

    try {
      if (Platform.isAndroid) {
        final granted = await _liveActivityChannel.invokeMethod<bool>(
          'requestNotificationPermission',
        );
        if (granted != true) {
          debugPrint('Android notification permission denied');
          return;
        }
      }

      await _liveActivityChannel.invokeMethod<String>('startLiveActivity', {
        'runId': _currentRunId,
        'title': '러닝 중',
        'elapsedSeconds': _seconds,
        'distanceMeters': _totalDistance,
        'paceText': _calculatePace(),
        'isPaused': _isPaused,
      });
    } catch (e) {
      debugPrint('Live Activity start failed: $e');
    }
  }

  Future<void> _updateLiveActivity() async {
    if (_currentRunId == null || !_isStarted) return;

    try {
      await _liveActivityChannel.invokeMethod<void>('updateLiveActivity', {
        'runId': _currentRunId,
        'elapsedSeconds': _seconds,
        'distanceMeters': _totalDistance,
        'paceText': _calculatePace(),
        'isPaused': _isPaused,
      });
    } catch (e) {
      debugPrint('Live Activity update failed: $e');
    }
  }

  Future<void> _endLiveActivity(String status) async {
    if (_currentRunId == null) return;

    try {
      await _liveActivityChannel.invokeMethod<void>('endLiveActivity', {
        'runId': _currentRunId,
        'status': status,
      });
    } catch (e) {
      debugPrint('Live Activity end failed: $e');
    }
  }

  void _togglePause() {
    if (_isPaused) {
      _startCountdown(isResuming: true);
      return;
    }

    setState(() {
      _session.pause();
    });
    _refreshRunningMetrics();
    _followCurrentLocationIfRunning();
    unawaited(_updateLiveActivity());
  }

  void _startTerritoryUpdates() {
    _territoryTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _fetchTerritories();
      _fetchUserRanking();
    });
  }

  Future<void> _fetchUserRanking({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastUserRankingFetchTime != null &&
        now.difference(_lastUserRankingFetchTime!).inSeconds < 5) {
      return _userRankingFetchFuture ?? Future.value();
    }

    final inFlight = _userRankingFetchFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = () async {
      _lastUserRankingFetchTime = now;
      try {
        final snapshot = await RunningMapService.instance.fetchUserProfile(
          force: true,
        );
        if (!mounted || snapshot == null) {
          return;
        }

        final String? newColor = snapshot.colorHex;
        setState(() {
          _currentUserId = snapshot.userId;
          _points = snapshot.totalPoints;
          _occupiedArea = snapshot.area / 1000000;
          _weightKg = snapshot.weightKg;
          _ranking = snapshot.rank;
          if (_isValidColorHex(newColor)) {
            _userColorHex = newColor!;
          }
        });

        if (_isValidColorHex(newColor)) {
          await _updateCurrentLocationIcon();
          if (mounted) {
            _updatePolylines();
          }
        }
      } catch (e) {
        debugPrint('유저 랭킹 정보 로드 실패: $e');
      }
    }();

    _userRankingFetchFuture = future;
    return future.whenComplete(() {
      if (identical(_userRankingFetchFuture, future)) {
        _userRankingFetchFuture = null;
      }
    });
  }

  Future<void> _updateCurrentLocationIcon() async {
    final color = _colorFromHex(_userColorHex);
    final icon = await _createDotIcon(color);
    if (mounted) {
      setState(() {
        _currentLocationIcon = icon;
      });
    }
  }

  Future<BitmapDescriptor> _createDotIcon(Color color) async {
    const double size = 36.0;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Small, high-contrast dot that stays visible without covering the map.
    final Paint whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, whitePaint);

    final Paint colorPaint = Paint()..color = color;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size * 0.36,
      colorPaint,
    );

    final img = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  bool _isValidColorHex(String? value) {
    if (value == null) return false;
    final normalized = value.trim().replaceFirst('#', '');
    return RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized);
  }

  Color _colorFromHex(String? value, {Color fallback = AppColors.primary}) {
    if (!_isValidColorHex(value)) return fallback;
    final normalized = value!.trim().replaceFirst('#', '');
    return Color(int.parse('0xFF$normalized'));
  }

  Future<void> _fetchTerritories({bool force = false}) async {
    if (_isFetchingTerritory) return;
    final now = DateTime.now();
    final throttleSeconds = force ? 1 : 3;
    if (_lastFetchTime != null &&
        now.difference(_lastFetchTime!).inSeconds < throttleSeconds) {
      return;
    }

    _isFetchingTerritory = true;
    _lastFetchTime = now;

    try {
      final data = await RunningMapService.instance.fetchTerritories(
        mapController: mapController,
        currentPosition: _currentPosition,
      );
      if (data == null) {
        return;
      }
      await _parseTerritoryGeoJson(data);
    } catch (e) {
      debugPrint("영토 데이터 로드 실패: $e");
    } finally {
      _isFetchingTerritory = false;
    }
  }

  Future<BitmapDescriptor> _createNicknameIcon(
    String nickname,
    Color color,
  ) async {
    final label = _shortenTerritoryLabel(nickname);
    final String cacheKey = "${label}_${color.toARGB32()}";
    if (_nicknameCache.containsKey(cacheKey)) return _nicknameCache[cacheKey]!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: label,
      style: TextStyle(
        fontSize: 22.0,
        fontWeight: FontWeight.bold,
        color: color,
        shadows: const [
          Shadow(
            offset: Offset(1.0, 1.0),
            blurRadius: 2.0,
            color: Colors.black38,
          ),
        ],
      ),
    );

    painter.layout();
    painter.paint(canvas, const Offset(0, 0));

    final img = await pictureRecorder.endRecording().toImage(
      painter.width.toInt(),
      painter.height.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final icon = BitmapDescriptor.bytes(data!.buffer.asUint8List());

    _nicknameCache[cacheKey] = icon;
    return icon;
  }

  String _shortenTerritoryLabel(String nickname) {
    final trimmed = nickname.trim();
    if (trimmed.length <= 8) return trimmed;
    return '${trimmed.substring(0, 7)}...';
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int i, j = polygon.length - 1;
    bool oddNodes = false;
    double x = point.longitude;
    double y = point.latitude;

    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude < y && polygon[j].latitude >= y ||
              polygon[j].latitude < y && polygon[i].latitude >= y) &&
          (polygon[i].longitude <= x || polygon[j].longitude <= x)) {
        if (polygon[i].longitude +
                (y - polygon[i].latitude) /
                    (polygon[j].latitude - polygon[i].latitude) *
                    (polygon[j].longitude - polygon[i].longitude) <
            x) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }
    return oddNodes;
  }

  double _getDistanceSq(LatLng p1, LatLng p2) {
    return (p1.latitude - p2.latitude) * (p1.latitude - p2.latitude) +
        (p1.longitude - p2.longitude) * (p1.longitude - p2.longitude);
  }

  double _pointToSegmentDistanceSq(LatLng p, LatLng v, LatLng w) {
    double l2 = _getDistanceSq(v, w);
    if (l2 == 0) return _getDistanceSq(p, v);
    double t =
        ((p.latitude - v.latitude) * (w.latitude - v.latitude) +
            (p.longitude - v.longitude) * (w.longitude - v.longitude)) /
        l2;
    t = t < 0 ? 0 : (t > 1 ? 1 : t);
    return _getDistanceSq(
      p,
      LatLng(
        v.latitude + t * (w.latitude - v.latitude),
        v.longitude + t * (w.longitude - v.longitude),
      ),
    );
  }

  LatLng _getPolygonCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);

    double minLat = points[0].latitude, maxLat = points[0].latitude;
    double minLng = points[0].longitude, maxLng = points[0].longitude;
    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    LatLng center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    // 1. 기본 중심점이 내부에 있다면 바로 반환
    if (_isPointInPolygon(center, points)) return center;

    // 2. 외부에 있다면 그리드 탐색을 통해 가장 "깊은(가장 넓은)" 점 탐색
    LatLng bestPoint = points[0];
    double maxDistSq = -1.0;

    // 10x10 그리드로 내부 탐색
    const int gridCount = 10;
    double latStep = (maxLat - minLat) / gridCount;
    double lngStep = (maxLng - minLng) / gridCount;

    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        LatLng candidate = LatLng(minLat + i * latStep, minLng + j * lngStep);
        if (_isPointInPolygon(candidate, points)) {
          // 모든 경계선으로부터의 최소 거리 계산
          double minDistSq = double.infinity;
          for (int k = 0; k < points.length; k++) {
            double d2 = _pointToSegmentDistanceSq(
              candidate,
              points[k],
              points[(k + 1) % points.length],
            );
            if (d2 < minDistSq) minDistSq = d2;
          }

          if (minDistSq > maxDistSq) {
            maxDistSq = minDistSq;
            bestPoint = candidate;
          }
        }
      }
    }
    return bestPoint;
  }

  LatLngBounds _getPolygonBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  double _getPolygonAreaScore(List<LatLng> points) {
    if (points.length < 3) return 0;

    double area = 0;
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      area +=
          current.longitude * next.latitude - next.longitude * current.latitude;
    }

    return area.abs() / 2;
  }

  void _collectLabelCandidate({
    required Map<String, _TerritoryLabelCandidate> candidates,
    required String userId,
    required String markerIdValue,
    required String nickname,
    required Color color,
    required LatLng center,
    required LatLngBounds bounds,
    required double areaScore,
  }) {
    final existing = candidates[userId];
    final candidate = _TerritoryLabelCandidate(
      userId: userId,
      markerIdValue: markerIdValue,
      nickname: nickname,
      color: color,
      center: center,
      bounds: bounds,
      areaScore: areaScore,
    );

    if (existing == null || candidate.areaScore > existing.areaScore) {
      candidates[userId] = candidate;
    }
  }

  Future<void> _focusTerritoryBounds(LatLngBounds bounds) async {
    if (mapController == null) return;

    _isProgrammaticCameraMove = true;
    final bool isSinglePoint =
        bounds.southwest.latitude == bounds.northeast.latitude &&
        bounds.southwest.longitude == bounds.northeast.longitude;

    if (isSinglePoint) {
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: bounds.northeast, zoom: 16.5),
        ),
      );
      return;
    }

    await mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 56),
    );
  }

  Future<void> _parseTerritoryGeoJson(Map<String, dynamic> geojson) async {
    final List features = geojson['features'] ?? [];
    final Set<Polygon> newPolygons = {};
    final Set<Marker> newMarkers = {};
    final Map<String, LatLngBounds> markerBounds = {};
    final Map<String, _TerritoryLabelCandidate> labelCandidates = {};
    final String? currentUserId = _currentUserId;

    for (int fIdx = 0; fIdx < features.length; fIdx++) {
      final feature = features[fIdx];
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      if (properties is! Map || geometry is! Map) {
        continue;
      }
      final String userId =
          properties['user_id']?.toString() ?? "unknown_$fIdx";
      final String nickname = properties['nick_name']?.toString() ?? '익명';
      final String colorHex = properties['color_hex']?.toString() ?? "#448AFF";

      Color baseColor = _colorFromHex(colorHex);
      Color fillColor = baseColor.withValues(alpha: 0.3);
      Color strokeColor = baseColor.withValues(alpha: 0.8);

      if (geometry['type'] == 'Polygon') {
        List coordsList = geometry['coordinates'][0];
        List<LatLng> points = coordsList
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();

        final String polyId = "poly_${userId}_f$fIdx";
        newPolygons.add(
          Polygon(
            polygonId: PolygonId(polyId),
            points: points,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: 2,
          ),
        );

        final center = _getPolygonCenter(points);
        final bounds = _getPolygonBounds(points);
        final markerIdValue = "label_$polyId";
        final isOwnTerritory = currentUserId != null && currentUserId == userId;
        if (isOwnTerritory) {
          _collectLabelCandidate(
            candidates: labelCandidates,
            userId: userId,
            markerIdValue: markerIdValue,
            nickname: nickname,
            color: baseColor,
            center: center,
            bounds: bounds,
            areaScore: _getPolygonAreaScore(points),
          );
        }
      } else if (geometry['type'] == 'MultiPolygon') {
        List multiCoords = geometry['coordinates'];
        for (int i = 0; i < multiCoords.length; i++) {
          List coordsList = multiCoords[i][0];
          List<LatLng> points = coordsList
              .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();

          final String polyId = "poly_${userId}_f${fIdx}_i$i";
          newPolygons.add(
            Polygon(
              polygonId: PolygonId(polyId),
              points: points,
              fillColor: fillColor,
              strokeColor: strokeColor,
              strokeWidth: 2,
            ),
          );

          final center = _getPolygonCenter(points);
          final bounds = _getPolygonBounds(points);
          final markerIdValue = "label_$polyId";
          final isOwnTerritory =
              currentUserId != null && currentUserId == userId;
          if (isOwnTerritory) {
            _collectLabelCandidate(
              candidates: labelCandidates,
              userId: userId,
              markerIdValue: markerIdValue,
              nickname: nickname,
              color: baseColor,
              center: center,
              bounds: bounds,
              areaScore: _getPolygonAreaScore(points),
            );
          }
        }
      }
    }

    for (final candidate in labelCandidates.values) {
      final icon = await _createNicknameIcon(
        candidate.nickname,
        candidate.color,
      );
      final markerIdValue = candidate.markerIdValue;
      newMarkers.add(
        Marker(
          markerId: MarkerId(markerIdValue),
          position: candidate.center,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
          onTap: () => _focusTerritoryBounds(candidate.bounds),
        ),
      );
      markerBounds[markerIdValue] = candidate.bounds;
    }

    if (mounted) {
      setState(() {
        _territoryPolygons.clear();
        _territoryPolygons.addAll(newPolygons);
        _territoryMarkers.clear();
        _territoryMarkers.addAll(newMarkers);
        _territoryMarkerBounds
          ..clear()
          ..addAll(markerBounds);
      });
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    final lastKnownPosition = await Geolocator.getLastKnownPosition();
    if (lastKnownPosition != null && mounted) {
      setState(() {
        _currentPosition = LatLng(
          lastKnownPosition.latitude,
          lastKnownPosition.longitude,
        );
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    try {
      final position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 8),
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('현재 위치 갱신 실패: $error');
    }
  }

  void _goToCurrentLocation({bool isAutomatic = false}) {
    if (_currentPosition != null && mapController != null) {
      if (isAutomatic && !_isStarted) {
        return;
      }
      if (isAutomatic &&
          (_hasAutoCenteredInitially || _hasUserInteractedWithMap)) {
        return;
      }
      _isProgrammaticCameraMove = true;
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: isAutomatic ? _runningFollowZoom : _manualLocateZoom,
          ),
        ),
      );
      if (isAutomatic) {
        _hasAutoCenteredInitially = true;
      } else if (_isStarted && !_isPaused) {
        _isFollowingUser = true;
      }
    }
  }

  void _followCurrentLocationIfRunning() {
    if (!_isStarted ||
        _isPaused ||
        !_isFollowingUser ||
        _currentPosition == null ||
        mapController == null) {
      return;
    }
    _isProgrammaticCameraMove = true;
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentPosition!, zoom: _runningFollowZoom),
      ),
    );
  }

  Future<void> _focusExternalTerritory(dynamic result) async {
    if (result is! Map) return;
    final action = result['action']?.toString();
    if (action != 'focus_territory') return;

    final lat = (result['lat'] as num?)?.toDouble();
    final lng = (result['lng'] as num?)?.toDouble();
    if (lat == null || lng == null || mapController == null) return;

    setState(() {
      _isFollowingUser = false;
      _hasUserInteractedWithMap = true;
    });
    _isProgrammaticCameraMove = true;
    await mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 16.5),
      ),
    );
  }

  void _startLocationTracking({required bool enableBackgroundUpdates}) {
    _positionStream?.cancel();
    final LocationSettings locationSettings = Platform.isIOS
        ? AppleSettings(
            accuracy: enableBackgroundUpdates
                ? LocationAccuracy.bestForNavigation
                : LocationAccuracy.high,
            activityType: enableBackgroundUpdates
                ? ActivityType.fitness
                : ActivityType.other,
            distanceFilter: 3,
            pauseLocationUpdatesAutomatically: !enableBackgroundUpdates,
            showBackgroundLocationIndicator: enableBackgroundUpdates,
            allowBackgroundLocationUpdates: enableBackgroundUpdates,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (mounted) {
              final newLatLng = LatLng(position.latitude, position.longitude);
              final routePoint = RunRoutePoint.fromPosition(position);
              final shouldRefreshTerritories = _currentPosition == null;
              setState(() {
                _currentPosition = newLatLng;

                if (_isCountdownActive && !_isStarted) {
                  _session.primeWarmupPosition(position);
                } else if (_isStarted && !_isPaused) {
                  final accepted = _session.addPositionSample(
                    position,
                    routePoint,
                  );
                  if (accepted) {
                    _updatePolylines();
                    unawaited(_updateLiveActivity());
                    unawaited(_announceSplitIfNeeded());
                  }
                }
              });
              if (shouldRefreshTerritories) {
                unawaited(_fetchTerritories(force: true));
              }
              _followCurrentLocationIfRunning();
            }
          },
          onError: (Object error) {
            debugPrint('위치 스트림 오류: $error');
          },
        );
  }

  void _updatePolylines() {
    setState(() {
      _polylines
        ..clear()
        ..addAll(_buildRoutePolylines());
    });
  }

  Set<Polyline> _buildRoutePolylines() {
    final userColor = _colorFromHex(_userColorHex);
    final pathColor = userColor.withValues(alpha: 0.5);
    final polylines = <Polyline>{};

    for (var i = 0; i < _routeSegments.length; i++) {
      final segment = _routeSegments[i];
      polylines.add(
        Polyline(
          polylineId: PolylineId('running_route_$i'),
          points: segment.map((point) => point.latLng).toList(growable: false),
          color: pathColor,
          width: 8,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    return polylines;
  }

  void _startRunning() {
    _lastAnnouncedSplitKm = 0;
    _lastAnnouncedSplitElapsedSeconds = 0;
    _startCountdown(isResuming: false);
  }

  void _startCountdown({required bool isResuming}) {
    if (_isCountdownActive) {
      return;
    }
    if (isResuming) {
      if (!_isStarted || !_isPaused) {
        return;
      }
    } else if (_isStarted) {
      return;
    }

    _countdownTimer?.cancel();
    _countdownEndAt = DateTime.now().add(const Duration(seconds: 3));
    _countdownIsResuming = isResuming;
    setState(() {
      _isCountdownActive = true;
      _countdownValue = 3;
      if (!isResuming) {
        _session.prepareForCountdown();
        _polylines.clear();
      }
    });

    if (Platform.isIOS) {
      unawaited(_beginIosCountdownBackgroundTask());
      unawaited(_ensureBackgroundReadyForRun());
      _startLocationTracking(enableBackgroundUpdates: true);
    }

    _tickCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _tickCountdown(),
    );
  }

  void _tickCountdown() {
    if (!mounted || !_isCountdownActive) {
      return;
    }
    final endAt = _countdownEndAt;
    if (endAt == null) {
      return;
    }

    final remainingMs = endAt.difference(DateTime.now()).inMilliseconds;
    if (remainingMs <= 0) {
      _completeCountdown();
      return;
    }

    final nextValue = ((remainingMs + 999) ~/ 1000).clamp(1, 3);
    if (_countdownValue != nextValue) {
      setState(() {
        _countdownValue = nextValue;
      });
    }
  }

  void _completeCountdown() {
    if (!_isCountdownActive) {
      return;
    }

    final isResuming = _countdownIsResuming;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownEndAt = null;
    _countdownIsResuming = false;
    unawaited(_endIosCountdownBackgroundTask());
    unawaited(_playRunStartEffect());

    if (isResuming) {
      _resumeRunning();
    } else {
      _beginRunning();
    }
  }

  void _resumeRunning() {
    setState(() {
      _isCountdownActive = false;
      _countdownEndAt = null;
      _session.resume(currentPosition: _currentPosition);
      _isFollowingUser = true;
    });

    _refreshRunningMetrics();
    _lastAnnouncedSplitKm = (_totalDistance / 1000).floor();
    _lastAnnouncedSplitElapsedSeconds = _seconds;
    _followCurrentLocationIfRunning();
    _ensureRunningTimer();
    unawaited(_updateLiveActivity());
  }

  void _beginRunning() {
    unawaited(_ensureBackgroundReadyForRun());
    _startLocationTracking(enableBackgroundUpdates: true);

    setState(() {
      _isCountdownActive = false;
      _countdownEndAt = null;
      _isFollowingUser = true;
      _session.beginRun(currentPosition: _currentPosition);
    });

    _followCurrentLocationIfRunning();
    _ensureRunningTimer();
    unawaited(_startLiveActivity());
  }

  Future<void> _ensureBackgroundReadyForRun() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('Location service is disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
      }

      if (Platform.isIOS) {
        if (permission != LocationPermission.always) {
          debugPrint(
            'Background location permission is not set to always: $permission',
          );
        }
      } else if (Platform.isAndroid) {
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          debugPrint('Android location permission is not granted: $permission');
        }
      }
    } catch (e) {
      debugPrint('Background location permission check failed: $e');
    }
  }

  Map<String, dynamic>? _extractSavedRunData(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data'] as Map);
      }
      if (decoded['run'] is Map) {
        return Map<String, dynamic>.from(decoded['run'] as Map);
      }
      return decoded;
    }

    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }

    return null;
  }

  Future<void> _stopRunning() async {
    if (_isFinishingRun || !_isStarted) {
      return;
    }

    _isFinishingRun = true;
    _timer?.cancel();
    _refreshRunningMetrics();
    try {
      if (Platform.isAndroid) {
        await _stopAndroidBackgroundTracking();
      }
      await _endLiveActivity('ended');

      final endTime = DateTime.now();
      final routeCopy = List<RunRoutePoint>.from(_routePointSamples);
      try {
        final finalPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        ).timeout(const Duration(seconds: 3));
        final shouldAppendFinalPoint =
            finalPosition.accuracy <= _maxAcceptedAccuracyMeters &&
            (routeCopy.isEmpty ||
                Geolocator.distanceBetween(
                      routeCopy.last.latitude,
                      routeCopy.last.longitude,
                      finalPosition.latitude,
                      finalPosition.longitude,
                    ) >=
                    _minMovementMeters);
        if (shouldAppendFinalPoint) {
          routeCopy.add(RunRoutePoint.fromPosition(finalPosition));
        }
      } catch (e) {
        debugPrint('종료 시점 최종 위치 확보 실패: $e');
      }

      if (routeCopy.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이동 경로가 충분히 기록되지 않아 러닝 기록을 저장할 수 없습니다.'),
            ),
          );
        }
        return;
      }

      final routeSegments = splitRoutePointSegments(routeCopy);
      if (routeSegments.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이동 경로가 충분히 기록되지 않아 러닝 기록을 저장할 수 없습니다.'),
            ),
          );
        }
        return;
      }

      final trackedDistanceMeters = _totalDistance;
      final sampledDistanceMeters = _distanceFromRouteSamples(routeCopy);
      final baselineDistanceMeters = math
          .max(trackedDistanceMeters, sampledDistanceMeters)
          .toDouble();

      double finalDistanceMeters = baselineDistanceMeters;
      final durationHours = _seconds / 3600;

      final splitDistanceProbe = _buildRunSplits(
        routePoints: routeCopy,
        totalDurationSeconds: _seconds,
      );
      final splitTotalDistanceMeters = _totalSplitDistanceMeters(
        splitDistanceProbe,
      );
      if (splitTotalDistanceMeters > 0) {
        finalDistanceMeters = splitTotalDistanceMeters;
      }

      final distanceKm = finalDistanceMeters / 1000;
      final avgSpeedKmH = durationHours > 0 ? distanceKm / durationHours : 0.0;
      final avgPaceSecondsPerKm = distanceKm > 0 ? _seconds / distanceKm : 0.0;

      const kv = 0.3;
      const vRef = 10.0;

      final rawPoint = distanceKm * (1 + kv * (avgSpeedKmH / vRef)) * 10;
      final calculatedPoint = double.parse(rawPoint.toStringAsFixed(2));
      var resolvedWeightKg = _weightKg;
      if (resolvedWeightKg == null ||
          !resolvedWeightKg.isFinite ||
          resolvedWeightKg <= 0) {
        try {
          final snapshot = await RunningMapService.instance.fetchUserProfile(
            force: true,
          );
          final fetchedWeight = snapshot?.weightKg;
          if (fetchedWeight != null &&
              fetchedWeight.isFinite &&
              fetchedWeight > 0) {
            resolvedWeightKg = fetchedWeight;
            if (mounted) {
              setState(() {
                _weightKg = fetchedWeight;
              });
            } else {
              _weightKg = fetchedWeight;
            }
          }
        } catch (e) {
          debugPrint('칼로리 계산용 체중 재조회 실패: $e');
        }
      }

      final calculatedCalories = _estimateCalories(
        distanceKm: distanceKm,
        durationHours: durationHours,
        avgSpeedKmH: avgSpeedKmH,
        weightKg: resolvedWeightKg,
      );

      final segmentedPathGeom = _pathGeomWithAltitude(routeSegments);
      final flattenedPathGeom = _pathGeomWithAltitude([routeCopy]);
      final runSplits = _buildRunSplits(
        routePoints: routeCopy,
        totalDurationSeconds: _seconds,
        totalCalories: calculatedCalories,
      );

      final Map<String, dynamic> resultData = {
        "started_at": _startTime?.toUtc().toIso8601String(),
        "ended_at": endTime.toUtc().toIso8601String(),
        "duration": _seconds,
        "distance": finalDistanceMeters,
        "point": calculatedPoint,
        "avg_pace": avgPaceSecondsPerKm,
        "calories": calculatedCalories,
        "total_ascent": _totalAscent,
        "path_geom": segmentedPathGeom,
        "splits": runSplits,
        "route_points": routeCopy.map((point) => point.toJson()).toList(),
      };

      Map<String, dynamic>? savedRunData;
      Future<Map<String, dynamic>?> tryCreateRun(String pathGeom) async {
        final decoded = await RunService.instance.createRun(
          payload: {
            "started_at": resultData["started_at"],
            "ended_at": resultData["ended_at"],
            "duration": resultData["duration"],
            "distance": resultData["distance"],
            "point": resultData["point"],
            "avg_pace": resultData["avg_pace"],
            "calories": resultData["calories"],
            "path_geom": pathGeom,
            "splits": resultData["splits"],
          },
        );
        return _extractSavedRunData(decoded);
      }

      try {
        savedRunData = await tryCreateRun(segmentedPathGeom);
        debugPrint("러닝 기록 서버 저장 성공");
      } catch (e) {
        debugPrint("세그먼트 경로 저장 실패, 단일 경로로 재시도합니다: $e");
        try {
          savedRunData = await tryCreateRun(flattenedPathGeom);
          debugPrint("단일 경로로 러닝 기록 서버 저장 성공");
        } catch (fallbackError) {
          debugPrint("러닝 기록 서버 전송 중 오류: $fallbackError");
        }
      }

      if (savedRunData == null) {
        _session.pause();
        _refreshRunningMetrics();
        _ensureRunningTimer();
        await _updateLiveActivity();
        setState(() {
          _isFollowingUser = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('러닝 기록 저장에 실패했습니다.')));
        }
        return;
      }

      savedRunData['route_points'] = routeCopy
          .map((point) => point.toJson())
          .toList();
      savedRunData['total_ascent'] = _totalAscent;
      if (calculatedCalories != null &&
          calculatedCalories.isFinite &&
          calculatedCalories > 0) {
        savedRunData['calories'] = calculatedCalories;
      }
      savedRunData['splits'] = runSplits;
      _startLocationTracking(enableBackgroundUpdates: false);

      setState(() {
        _isFollowingUser = false;
        _session.reset();
        _polylines.clear();
      });
      _lastAnnouncedSplitKm = 0;
      _lastAnnouncedSplitElapsedSeconds = 0;

      if (mounted) {
        if (calculatedCalories == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('체중 정보가 없어 칼로리 계산을 하지 못했습니다.')),
          );
        }
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RunResultPage(runData: savedRunData!),
          ),
        );
        await _focusExternalTerritory(result);
        _fetchUserRanking(force: true);
        _fetchTerritories(force: true);
      }
    } finally {
      _isFinishingRun = false;
    }
  }

  Future<void> _cancelRunning({bool skipDialog = false}) async {
    if (skipDialog) {
      _timer?.cancel();
      if (Platform.isAndroid) {
        await _stopAndroidBackgroundTracking();
      }
      await _endLiveActivity('cancelled');
      _startLocationTracking(enableBackgroundUpdates: false);
      setState(() {
        _isFollowingUser = false;
        _session.reset();
        _polylines.clear();
      });
      _lastAnnouncedSplitKm = 0;
      _lastAnnouncedSplitElapsedSeconds = 0;
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                "러닝 취소",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "현재 러닝을 취소하시겠습니까?\n기록은 저장되지 않습니다.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "아니오",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _cancelRunning(skipDialog: true);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "예",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleZoom(bool isZoomIn) {
    mapController?.animateCamera(CameraUpdate.zoomBy(isZoomIn ? 1 : -1));
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _calculatePace() {
    if (_totalDistance < 10) return "-'--\"";
    double paceDecimal = (_seconds / 60) / (_totalDistance / 1000);
    int m = paceDecimal.toInt();
    int s = ((paceDecimal - m) * 60).toInt();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  Widget _buildTopBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: AppSurface(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        color: Colors.white.withValues(alpha: 0.95),
        radius: 22,
        shadow: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TerritoryDetailPage(),
                  ),
                );
              },
              child: _buildTopBannerItem(
                Icons.grid_view_rounded,
                "점령 면적",
                "${_occupiedArea.toStringAsFixed(2)} km²",
              ),
            ),
            _buildTopDivider(),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RankingPage()),
                );
              },
              child: _buildTopBannerItem(
                Icons.leaderboard_rounded,
                "랭킹",
                "$_ranking위",
              ),
            ),
            _buildTopDivider(),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PointHistoryPage(),
                  ),
                );
              },
              child: _buildTopBannerItem(
                Icons.stars_rounded,
                "포인트",
                "${_points.toStringAsFixed(2)} P",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopDivider() =>
      Container(width: 1, height: 20, color: Colors.black12);

  Widget _buildTopBannerItem(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
      bottom: _isStarted ? -120 : 40,
      left: 20,
      right: 20,
      child: AppSurface(
        height: 80,
        padding: EdgeInsets.zero,
        color: Colors.white.withValues(alpha: 0.95),
        radius: 40,
        shadow: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.insights_rounded, "분석", false, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsPage()),
              );
            }),
            _buildNavItem(Icons.bar_chart_rounded, "통계", false, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RunHistoryPage()),
              );
            }),
            const SizedBox(width: 80),
            _buildNavItem(Icons.people_rounded, "소셜", false, null),
            _buildNavItem(Icons.person_rounded, "마이", false, () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyPage()),
              );

              if (result == true) {
                _fetchUserRanking(force: true);
                _fetchTerritories(force: true);
                _nicknameCache.clear();
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.primary : Colors.grey[400],
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? AppColors.primary : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
      right: 20,
      bottom: _isStarted ? 320 : 140,
      child: Column(
        children: [
          _buildCompassButton(),
          const SizedBox(height: 12),
          _buildZoomButton(Icons.my_location, _goToCurrentLocation),
          const SizedBox(height: 12),
          _buildZoomButton(Icons.add, () => _handleZoom(true)),
          const SizedBox(height: 12),
          _buildZoomButton(Icons.remove, () => _handleZoom(false)),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AppSurface(
        width: 48,
        height: 48,
        padding: EdgeInsets.zero,
        color: Colors.white.withValues(alpha: 0.92),
        radius: 24,
        shadow: true,
        child: Icon(icon, color: AppColors.text, size: 24),
      ),
    );
  }

  Widget _buildCompassButton() {
    final isNorthAligned = _currentBearing.abs() < _compassResetThreshold;

    return GestureDetector(
      onTap: isNorthAligned ? null : _resetMapNorth,
      child: Opacity(
        opacity: isNorthAligned ? 0.55 : 1,
        child: AppSurface(
          width: 48,
          height: 48,
          padding: EdgeInsets.zero,
          color: Colors.white.withValues(alpha: 0.92),
          radius: 24,
          shadow: true,
          child: Center(
            child: Transform.rotate(
              angle: (-_currentBearing * math.pi) / 180,
              child: Icon(
                Icons.navigation_rounded,
                color: isNorthAligned
                    ? Colors.grey[500]
                    : AppColors.destructive,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetMapNorth() {
    final target = _currentCameraTarget ?? _currentPosition;
    if (mapController == null || target == null) {
      return;
    }

    _isProgrammaticCameraMove = true;
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: _currentZoom, bearing: 0),
      ),
    );
  }

  Widget _buildUnifiedControlPanel() {
    const double buttonSize = 80.0;

    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: IgnorePointer(
              ignoring: _isStarted,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                opacity: _isStarted ? 0 : 1,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  scale: _isStarted ? 0.92 : 1,
                  child: SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(buttonSize / 2),
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: 0.18),
                      child: InkWell(
                        onTap: _startRunning,
                        borderRadius: BorderRadius.circular(buttonSize / 2),
                        child: const Center(
                          child: Icon(
                            Icons.directions_run,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: IgnorePointer(
              ignoring: !_isStarted,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                opacity: _isStarted ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 460),
                  curve: Curves.easeOutCubic,
                  offset: _isStarted ? Offset.zero : const Offset(0, 1.1),
                  child: _buildRunningControlSheet(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningControlSheet() {
    return AppSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: Colors.white.withValues(alpha: 0.98),
      radius: 30,
      shadow: true,
      child: Column(
        key: const ValueKey("running_panel"),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatTime(_seconds),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  "거리",
                  "${(_totalDistance / 1000).toStringAsFixed(2)} km",
                  AppColors.primary,
                ),
              ),
              Expanded(
                child: _buildStatItem("페이스", _calculatePace(), Colors.green),
              ),
              Expanded(
                child: _buildStatItem(
                  "속도",
                  "${(_currentSpeed * 3.6).toStringAsFixed(1)} km/h",
                  Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                _circleButton(
                  icon: Icons.close,
                  color: AppColors.secondaryText,
                  onTap: () {
                    unawaited(_cancelRunning());
                  },
                ),
                _circleButton(
                  icon: _isPaused ? Icons.play_arrow : Icons.pause,
                  color: AppColors.warning,
                  onTap: _togglePause,
                ),
                _circleButton(
                  icon: Icons.stop,
                  color: AppColors.destructive,
                  onTap: () {
                    unawaited(_stopRunning());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AppSurface(
        width: 56,
        height: 56,
        padding: EdgeInsets.zero,
        color: color,
        radius: 28,
        shadow: true,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          transitionBuilder: (child, animation) {
            final isVisible = child.key == const ValueKey('countdown_visible');
            final scaleAnimation = CurvedAnimation(
              parent: animation,
              curve: isVisible ? Curves.easeOutBack : Curves.easeInCubic,
            );
            final opacityAnimation = CurvedAnimation(
              parent: animation,
              curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
            );
            final scale = Tween<double>(
              begin: isVisible ? 0.86 : 1.0,
              end: isVisible ? 1.0 : 0.9,
            ).animate(scaleAnimation);
            return FadeTransition(
              opacity: opacityAnimation,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
          child: !_isCountdownActive
              ? const SizedBox.shrink(key: ValueKey('countdown_hidden'))
              : Container(
                  key: const ValueKey('countdown_visible'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 156,
                    height: 156,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.98),
                                const Color(0xFFF3F8FF).withValues(alpha: 0.96),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0090FF,
                                ).withValues(alpha: 0.14),
                                blurRadius: 28,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 18,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 148,
                          height: 148,
                          child: TweenAnimationBuilder<double>(
                            key: const ValueKey('countdown_ring'),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(seconds: 3),
                            curve: Curves.linear,
                            builder: (context, value, child) {
                              return CircularProgressIndicator(
                                value: value,
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                backgroundColor: const Color(
                                  0xFF0090FF,
                                ).withValues(alpha: 0.12),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0090FF),
                                ),
                              );
                            },
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            final scale = Tween<double>(
                              begin: 0.82,
                              end: 1.0,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            '$_countdownValue',
                            key: ValueKey(_countdownValue),
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color userColor = _colorFromHex(_userColorHex);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  style: _mapStyle,
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                    _currentCameraTarget ??=
                        widget.initialFocusTarget ?? _currentPosition;
                    _fetchTerritories();
                    if (widget.initialFocusTarget != null) {
                      _isProgrammaticCameraMove = true;
                      _hasUserInteractedWithMap = true;
                      mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: widget.initialFocusTarget!,
                            zoom: widget.initialFocusZoom,
                          ),
                        ),
                      );
                    }
                    if (_isStarted && !_isPaused) {
                      _followCurrentLocationIfRunning();
                    } else if (_currentPosition != null &&
                        widget.initialFocusTarget == null) {
                      _goToCurrentLocation(isAutomatic: true);
                    }
                  },
                  onCameraMoveStarted: () {
                    if (!_isProgrammaticCameraMove) {
                      _hasUserInteractedWithMap = true;
                      if (_isStarted && !_isPaused) {
                        _isFollowingUser = false;
                      }
                    }
                  },
                  onCameraMove: (position) {
                    final shouldRefreshBearing =
                        (_currentBearing - position.bearing).abs() >= 1;
                    _currentZoom = position.zoom;
                    _currentBearing = position.bearing;
                    _currentCameraTarget = position.target;
                    if (shouldRefreshBearing && mounted) {
                      setState(() {});
                    }
                  },
                  onCameraIdle: () {
                    _isProgrammaticCameraMove = false;
                    _fetchTerritories();
                  },
                  initialCameraPosition: CameraPosition(
                    target:
                        widget.initialFocusTarget ??
                        _currentPosition ??
                        const LatLng(37.5665, 126.9780),
                    zoom: 16,
                  ),
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  buildingsEnabled: false,
                  polylines: _polylines,
                  polygons: _territoryPolygons,
                  markers: _territoryMarkers.toSet().union({
                    if (_currentPosition != null)
                      Marker(
                        markerId: const MarkerId('current_location'),
                        position: _currentPosition!,
                        icon:
                            _currentLocationIcon ??
                            BitmapDescriptor.defaultMarker,
                        anchor: const Offset(0.5, 0.5),
                        zIndexInt: 10,
                      ),
                  }),
                  circles: {
                    if (_currentPosition != null)
                      Circle(
                        circleId: const CircleId('current_location_accuracy'),
                        center: _currentPosition!,
                        radius: 12,
                        fillColor: userColor.withValues(alpha: 0.2),
                        strokeColor: userColor.withValues(alpha: 0.5),
                        strokeWidth: 2,
                      ),
                  },
                ),
                _buildTopBanner(),
                _buildBottomNavBar(),
                _buildUnifiedControlPanel(),
                _buildZoomControls(),
                _buildCountdownOverlay(),
              ],
            ),
    );
  }
}

class _TerritoryLabelCandidate {
  const _TerritoryLabelCandidate({
    required this.userId,
    required this.markerIdValue,
    required this.nickname,
    required this.color,
    required this.center,
    required this.bounds,
    required this.areaScore,
  });

  final String userId;
  final String markerIdValue;
  final String nickname;
  final Color color;
  final LatLng center;
  final LatLngBounds bounds;
  final double areaScore;
}
