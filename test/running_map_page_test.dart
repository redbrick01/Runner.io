import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runner_flutter/main/running_map_page.dart';
import 'package:runner_flutter/services/territory_service.dart';

void main() {
  setUpAll(() {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
  });

  Widget buildSubject({
    FetchMapTerritories? fetchTerritories,
  }) {
    return MaterialApp(
      home: RunningMapPage(fetchTerritories: fetchTerritories),
    );
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

    testWidgets('shows personal and crew map modes', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('개인'), findsWidgets);
      expect(find.text('크루'), findsWidgets);
      expect(find.text('친구'), findsNothing);
      expect(find.textContaining('경쟁'), findsNothing);
    });

    testWidgets('uses default individual map for personal and crew scope for crew', (
      tester,
    ) async {
      final requestedScopes = <TerritoryScope?>[];

      await tester.pumpWidget(
        buildSubject(
          fetchTerritories:
              ({required mapController, required currentPosition, scope}) async {
                requestedScopes.add(scope);
                return null;
              },
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('크루').first);
      await tester.pumpAndSettle();

      expect(requestedScopes, contains(TerritoryScope.crew));

      await tester.tap(find.text('개인').first);
      await tester.pumpAndSettle();

      expect(requestedScopes, contains(isNull));
    });

    testWidgets('dismisses location warning when opening social page', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('기기 위치 서비스가 꺼져 있어 현재 위치를 불러올 수 없습니다.'),
        findsOneWidget,
      );

      await tester.tap(find.text('소셜'));
      await tester.pumpAndSettle();

      expect(find.text('소셜'), findsOneWidget);
      expect(
        find.text('기기 위치 서비스가 꺼져 있어 현재 위치를 불러올 수 없습니다.'),
        findsNothing,
      );
    });
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
