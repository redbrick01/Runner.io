import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/models/run_result.dart';
import 'run_result_screen.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key});

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSub;
  final List<LatLng> _route = [];

  double _distanceMeters = 0;
  Duration _elapsed = Duration.zero;

  Timer? _timer;
  DateTime? _startTime;

  bool _isRunning = false;

  // 하트레이트/칼로리 (아직 기능 X → 더미 데이터)
  int _heartRate = 0;
  double _calories = 0;

  // -----------------------
  // 계산용 getter
  // -----------------------
  double get _distanceKm => _distanceMeters / 1000;

  String get _formattedDuration {
    final totalSeconds = _elapsed.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  String get _formattedPace {
    if (_distanceKm <= 0) return "--:--";

    final secPerKm = _elapsed.inSeconds / _distanceKm;

    final totalSecondsPerKm = secPerKm.round();

    final minutes = (totalSecondsPerKm ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSecondsPerKm % 60).toString().padLeft(2, '0');

    return "$minutes:$seconds";
  }

  // --------------------------
  // Google Map 기본 카메라
  // --------------------------
  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(37.5665, 126.9780), // 서울 임시 좌표
    zoom: 15,
  );

  Set<Polyline> get _polylines {
    return {
      Polyline(
        polylineId: const PolylineId("route"),
        color: Colors.purple,
        width: 5,
        points: _route,
      ),
    };
  }

  // --------------------------
  // Lifecycle
  // --------------------------
  @override
  void initState() {
    super.initState();
    _startRun();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // --------------------------
  // RUN 시작
  // --------------------------
  Future<void> _startRun() async {
    // 위치 권한 체크
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
    }

    final pos = await Geolocator.getCurrentPosition();

    setState(() {
      _route.clear();
      _route.add(LatLng(pos.latitude, pos.longitude));

      _distanceMeters = 0;
      _elapsed = Duration.zero;

      _startTime = DateTime.now();
      _isRunning = true;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
    );

    // 위치 스트림
    _positionSub = Geolocator.getPositionStream().listen((p) {
      final newPoint = LatLng(p.latitude, p.longitude);

      setState(() {
        if (_route.isNotEmpty) {
          final last = _route.last;
          _distanceMeters += Geolocator.distanceBetween(
            last.latitude,
            last.longitude,
            newPoint.latitude,
            newPoint.longitude,
          );
        }
        _route.add(newPoint);
      });
    });

    // 타이머 시작
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
      });
    });
  }

  // --------------------------
  // STOP 버튼
  // --------------------------
  void _onStopPressed() {
    if (!_isRunning || _startTime == null) return;

    _positionSub?.cancel();
    _timer?.cancel();

    final end = DateTime.now();

    final result = RunResult(
      startAt: _startTime!,
      endAt: end,
      distanceMeters: _distanceMeters,
      duration: _elapsed,
      route: List<LatLng>.from(_route),
      calories: _calories,
      areaKm2: 0,
      point: 0,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RunResultScreen(result: result)),
    );
  }

  // --------------------------
  // UI
  // --------------------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF30579B),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // 지도
            Container(
              height: size.height * 0.45,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: GoogleMap(
                  initialCameraPosition: _initialCameraPosition,
                  onMapCreated: (c) => _mapController = c,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 아래 카드
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _StatItem(
                              label: "Duration",
                              value: _formattedDuration,
                            ),
                            _StatItem(
                              label: "Distance",
                              value: "${_distanceKm.toStringAsFixed(2)} km",
                            ),
                            _StatItem(
                              label: "Avg. Pace",
                              value: _formattedPace,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _StatItem(
                              label: "Heart Rate",
                              value: _heartRate.toString(),
                            ),
                            _StatItem(
                              label: "Calories",
                              value: _calories.toStringAsFixed(0),
                            ),
                            const SizedBox(width: 80),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _onStopPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5E5E5),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "STOP",
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
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
