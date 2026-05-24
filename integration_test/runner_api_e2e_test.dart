import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const _baseUrl = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const _configuredEmail = String.fromEnvironment('RUNNER_E2E_EMAIL');
const _configuredPassword = String.fromEnvironment('RUNNER_E2E_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create-run persists derived run data and ranking state', (
    tester,
  ) async {
    if (_baseUrl.isEmpty || _anonKey.isEmpty) {
      markTestSkipped('SUPABASE_URL and SUPABASE_ANON_KEY are required');
      return;
    }

    final auth = _configuredEmail.isNotEmpty && _configuredPassword.isNotEmpty
        ? await _signIn(_configuredEmail, _configuredPassword)
        : await _signUpUniqueUser();
    final otherAuth = await _signUpUniqueUser();

    final userId = auth.userId;
    final token = auth.accessToken;
    final dayKey = _kstToday();
    final beforeDaily = await _fetchDailyPoints(token, userId, dayKey);
    final beforeTotal = beforeDaily?['total_points'] as num? ?? 0;
    final beforeRun = beforeDaily?['run_points'] as num? ?? 0;

    final point = 1.23;
    final run = await _createRun(token, point: point);
    final runId = run['id'] as num;

    expect(run['user_id'], userId);
    expect((run['point'] as num).toDouble(), closeTo(point, 0.001));
    expect(run['loop_geom'], isNotNull);
    expect((run['area'] as num?)?.toDouble(), greaterThan(0));

    final history =
        await _getJson(
              token,
              '/functions/v1/run-history',
              queryParameters: {'limit': '5'},
            )
            as Map<String, dynamic>;
    final historyItems = history['items'] as List<dynamic>;
    final savedRun = historyItems.cast<Map<String, dynamic>>().firstWhere(
      (item) => item['id'] == runId,
    );
    expect((savedRun['point'] as num).toDouble(), closeTo(point, 0.001));
    expect(savedRun['splits'], isA<List<dynamic>>());
    expect(savedRun['splits'] as List<dynamic>, isNotEmpty);

    final pointHistory =
        await _getJson(
              token,
              '/functions/v1/point-history',
              queryParameters: {'limit': '10'},
            )
            as Map<String, dynamic>;
    final pointItems = (pointHistory['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      pointItems.any(
        (item) =>
            item['event_type'] == 'run_created' &&
            ((item['points_delta'] as num).toDouble() - point).abs() < 0.001,
      ),
      isTrue,
    );

    final daily = await _fetchDailyPoints(token, userId, dayKey);
    expect(daily, isNotNull);
    expect(daily!['day_kst'], dayKey);
    expect(
      (daily['total_points'] as num).toDouble(),
      closeTo(beforeTotal.toDouble() + point, 0.001),
    );
    expect(
      (daily['run_points'] as num).toDouble(),
      closeTo(beforeRun.toDouble() + point, 0.001),
    );

    final ranking =
        await _getJson(
              token,
              '/functions/v1/profile-leaderboard',
              queryParameters: {
                'mode': 'context',
                'range_type': 'day',
                'anchor_date': dayKey,
                'user_id': userId,
              },
            )
            as Map<String, dynamic>;
    final rankingUser = ranking['user'] as Map<String, dynamic>;
    expect(rankingUser['user_id'], userId);
    expect(
      (rankingUser['total_points'] as num).toDouble(),
      closeTo((daily['total_points'] as num).toDouble(), 0.001),
    );

    final otherHistory =
        await _getJson(
              otherAuth.accessToken,
              '/functions/v1/run-history',
              queryParameters: {'limit': '100'},
            )
            as Map<String, dynamic>;
    final otherHistoryItems = (otherHistory['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      otherHistoryItems.any((item) => item['id'] == runId),
      isFalse,
      reason: 'run-history must not expose another user run',
    );
  });
}

Future<_AuthSession> _signUpUniqueUser() async {
  final suffix = DateTime.now().microsecondsSinceEpoch;
  final email = 'runner_e2e_$suffix@example.com';
  final password = 'RunnerE2E!$suffix';
  final response = await http.post(
    Uri.parse('$_baseUrl/auth/v1/signup'),
    headers: _headers(includeJson: true),
    body: jsonEncode({'email': email, 'password': password}),
  );
  final decoded = _decode(response);
  return _AuthSession.fromJson(decoded);
}

Future<_AuthSession> _signIn(String email, String password) async {
  final response = await http.post(
    Uri.parse(
      '$_baseUrl/auth/v1/token',
    ).replace(queryParameters: {'grant_type': 'password'}),
    headers: _headers(includeJson: true),
    body: jsonEncode({'email': email, 'password': password}),
  );
  final decoded = _decode(response);
  return _AuthSession.fromJson(decoded);
}

Future<Map<String, dynamic>?> _fetchDailyPoints(
  String token,
  String userId,
  String dayKey,
) async {
  final decoded =
      await _getJson(
            token,
            '/rest/v1/user_point_daily',
            queryParameters: {
              'user_id': 'eq.$userId',
              'day_kst': 'eq.$dayKey',
              'select':
                  'user_id,day_kst,total_points,run_points,territory_points,other_points',
            },
          )
          as List<dynamic>;
  if (decoded.isEmpty) return null;
  return decoded.first as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _createRun(
  String token, {
  required double point,
}) async {
  final now = DateTime.now().toUtc();
  final startedAt = now.subtract(const Duration(minutes: 6));
  final endedAt = startedAt.add(const Duration(minutes: 4));
  final offset = (now.microsecondsSinceEpoch % 1000) / 10000000;
  final minLng = 127.02 + offset;
  final minLat = 37.52 + offset;
  final maxLng = minLng + 0.001;
  final maxLat = minLat + 0.001;
  final path =
      'LINESTRING Z($minLng $minLat 8, $maxLng $minLat 9, $maxLng $maxLat 10, $minLng $maxLat 8, $minLng $minLat 8)';

  final response = await http.post(
    Uri.parse('$_baseUrl/functions/v1/create-run'),
    headers: _headers(token: token, includeJson: true),
    body: jsonEncode({
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'duration': 240,
      'distance': 330.0,
      'point': point,
      'avg_pace': 727.27,
      'calories': null,
      'path_geom': path,
      'splits': [
        {
          'split_index': 1,
          'distance_m': 330.0,
          'duration_s': 240,
          'avg_pace_s_per_km': 727.27,
          'avg_speed_mps': 1.375,
          'ascent_m': 2,
          'calories': null,
          'path_geom': path,
        },
      ],
    }),
  );
  return _decode(response);
}

Future<dynamic> _getJson(
  String token,
  String path, {
  Map<String, String>? queryParameters,
}) async {
  final response = await http.get(
    Uri.parse('$_baseUrl$path').replace(queryParameters: queryParameters),
    headers: _headers(token: token),
  );
  return _decode(response);
}

Map<String, String> _headers({String? token, bool includeJson = false}) {
  return {
    'apikey': _anonKey,
    'Authorization': 'Bearer ${token ?? _anonKey}',
    if (includeJson) 'Content-Type': 'application/json',
  };
}

dynamic _decode(http.Response response) {
  final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    fail('HTTP ${response.statusCode}: ${response.body}');
  }
  return decoded;
}

String _kstToday() {
  final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
  final year = kst.year.toString().padLeft(4, '0');
  final month = kst.month.toString().padLeft(2, '0');
  final day = kst.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _AuthSession {
  const _AuthSession({required this.accessToken, required this.userId});

  final String accessToken;
  final String userId;

  factory _AuthSession.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token']?.toString();
    final user = json['user'];
    final userId = user is Map<String, dynamic> ? user['id']?.toString() : null;
    if (accessToken == null || accessToken.isEmpty || userId == null) {
      fail('Auth response did not include a session: ${jsonEncode(json)}');
    }
    return _AuthSession(accessToken: accessToken, userId: userId);
  }
}
