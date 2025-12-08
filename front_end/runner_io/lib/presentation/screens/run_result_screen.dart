import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/models/run_result.dart';
import '../../data/services/run_service.dart';
import 'home_screen.dart';

class RunResultScreen extends StatelessWidget {
  final RunResult result;

  const RunResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final polyline = Polyline(
      polylineId: const PolylineId('run_path'),
      color: Colors.purple,
      width: 5,
      points: result.route,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF315B9A),
      body: SafeArea(
        child: Column(
          children: [
            // 위 지도 (이번 러닝 루트)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 320,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: result.route.isNotEmpty
                          ? result.route.first
                          : const LatLng(37.5, 127.0),
                      zoom: 16,
                    ),
                    polylines: {polyline},
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                  ),
                ),
              ),
            ),

            // 아래 카드
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'YOU GOT',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${result.areaKm2.toStringAsFixed(2)}KM2 / ${result.point.toStringAsFixed(0)} POINTS',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Metric(title: 'Duration', value: result.durationText),
                        _Metric(
                          title: 'Distance',
                          value: '${result.distanceKm.toStringAsFixed(2)} km',
                        ),
                        _Metric(title: 'Avg. Pace', value: result.avgPaceText),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const _Metric(title: 'Heart Rate', value: '000'),
                        _Metric(
                          title: 'Calories',
                          value: result.calories.toStringAsFixed(0),
                        ),
                        _Metric(
                          title: 'Area',
                          value: '${result.areaKm2.toStringAsFixed(2)} km2',
                        ),
                      ],
                    ),
                    const Spacer(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () async {
                              try {
                                // Supabase run-create 호출
                                await RunService.instance.saveRun(result);

                                // 저장 완료되면 홈으로 (기존 스택 제거)
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const HomeScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('저장에 실패했습니다.')),
                                );
                              }
                            },
                            child: const Text('SAVE'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            // TODO: 나중에 공유 기능 추가
                          },
                          icon: const Icon(Icons.share),
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
    );
  }
}

class _Metric extends StatelessWidget {
  final String title;
  final String value;
  const _Metric({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
