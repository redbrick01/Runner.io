import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runner_flutter/main/running_map_page.dart';

void main() {
  setUpAll(() {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
  });

  Widget buildSubject() {
    return const MaterialApp(home: RunningMapPage());
  }

  group('RunningMapPage', () {
    testWidgets(
      'renders without crashing while native services are unavailable',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(RunningMapPage), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(RunningMapPage), findsOneWidget);
        expect(find.text('점령 면적'), findsOneWidget);
        expect(find.text('랭킹'), findsOneWidget);
        expect(find.text('포인트'), findsOneWidget);
        expect(find.text('분석'), findsOneWidget);
        expect(find.text('통계'), findsOneWidget);
        expect(find.text('마이'), findsOneWidget);
      },
    );
  });
}

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    throw const LocationServiceDisabledException();
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return const Stream<Position>.empty();
  }
}
