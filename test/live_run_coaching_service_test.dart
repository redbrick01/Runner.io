import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/services/live_run_coaching_service.dart';
import 'package:runner_flutter/services/live_run_coaching_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LiveRunCoachingRequest', () {
    test('serializes current split snapshot payload', () {
      const request = LiveRunCoachingRequest(
        runSessionId: 'session-1',
        completedKm: 3,
        elapsedSeconds: 1020,
        distanceMeters: 3000,
        splitDurationSeconds: 348,
        splitPaceSeconds: 348,
        averagePaceSeconds: 341,
        previousSplitPaces: [330, 336],
        currentSpeedKmh: 10.1,
        ascentThisSplitMeters: 3.2,
        pauseCount: 1,
        recentCoachingCategories: ['pace_control'],
      );

      final json = request.toJson();

      expect(json['run_session_id'], 'session-1');
      expect(json['completed_km'], 3);
      expect(json['previous_split_paces'], [330, 336]);
      expect(json['recent_coaching_categories'], ['pace_control']);
    });
  });

  group('LiveRunCoachingResponse', () {
    test('parses server response with fallback metadata', () {
      final response = LiveRunCoachingResponse.fromMap({
        'status': 'completed',
        'coaching_message': '비슷한 기록보다 안정적이에요. 지금 리듬을 이어가세요.',
        'coaching_category': 'steady',
        'similar_segment_count': 4,
        'fallback_used': false,
      });

      expect(response.status, 'completed');
      expect(response.coachingMessage, contains('안정적'));
      expect(response.coachingCategory, 'steady');
      expect(response.similarSegmentCount, 4);
      expect(response.fallbackUsed, isFalse);
    });
  });

  group('LiveRunCoachingSettings', () {
    test('defaults to enabled and persists changes', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await LiveRunCoachingSettings.instance.isEnabled(), isTrue);

      await LiveRunCoachingSettings.instance.setEnabled(false);

      expect(await LiveRunCoachingSettings.instance.isEnabled(), isFalse);
    });
  });
}
