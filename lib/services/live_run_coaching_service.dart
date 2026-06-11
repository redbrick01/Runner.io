import 'dart:async';

import 'supabase_api.dart';

class LiveRunCoachingRequest {
  const LiveRunCoachingRequest({
    required this.runSessionId,
    required this.completedKm,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.splitDurationSeconds,
    required this.splitPaceSeconds,
    required this.averagePaceSeconds,
    required this.previousSplitPaces,
    required this.currentSpeedKmh,
    required this.ascentThisSplitMeters,
    required this.pauseCount,
    required this.recentCoachingCategories,
    this.goalPaceSeconds,
    this.excludeRunId,
  });

  final String runSessionId;
  final int completedKm;
  final int elapsedSeconds;
  final double distanceMeters;
  final double splitDurationSeconds;
  final double splitPaceSeconds;
  final double averagePaceSeconds;
  final List<double> previousSplitPaces;
  final double? currentSpeedKmh;
  final double ascentThisSplitMeters;
  final int pauseCount;
  final List<String> recentCoachingCategories;
  final double? goalPaceSeconds;
  final int? excludeRunId;

  Map<String, dynamic> toJson() {
    return {
      'run_session_id': runSessionId,
      'completed_km': completedKm,
      'elapsed_seconds': elapsedSeconds,
      'distance_meters': distanceMeters,
      'split_duration_seconds': splitDurationSeconds,
      'split_pace_seconds': splitPaceSeconds,
      'average_pace_seconds': averagePaceSeconds,
      'previous_split_paces': previousSplitPaces,
      'current_speed_kmh': currentSpeedKmh,
      'ascent_this_split_m': ascentThisSplitMeters,
      'pause_count': pauseCount,
      'goal_pace_seconds': goalPaceSeconds,
      'recent_coaching_categories': recentCoachingCategories,
      'exclude_run_id': excludeRunId,
    };
  }
}

class LiveRunCoachingResponse {
  const LiveRunCoachingResponse({
    required this.status,
    required this.coachingMessage,
    required this.coachingCategory,
    required this.similarSegmentCount,
    required this.fallbackUsed,
  });

  final String status;
  final String coachingMessage;
  final String coachingCategory;
  final int similarSegmentCount;
  final bool fallbackUsed;

  factory LiveRunCoachingResponse.fromMap(Map<String, dynamic> raw) {
    return LiveRunCoachingResponse(
      status: raw['status']?.toString() ?? 'failed',
      coachingMessage: raw['coaching_message']?.toString().trim() ?? '',
      coachingCategory: raw['coaching_category']?.toString().trim() ?? 'steady',
      similarSegmentCount: _asInt(raw['similar_segment_count']),
      fallbackUsed: raw['fallback_used'] == true,
    );
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class LiveRunCoachingService {
  LiveRunCoachingService._();

  static final LiveRunCoachingService instance = LiveRunCoachingService._();

  Future<LiveRunCoachingResponse?> generateCoaching(
    LiveRunCoachingRequest request, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final decoded = await SupabaseApi.postFunctionJson(
      'generate-live-run-coaching',
      body: request.toJson(),
    ).timeout(timeout);
    final raw = SupabaseApi.requireJsonMap(
      decoded,
      'generate-live-run-coaching',
    );
    final response = LiveRunCoachingResponse.fromMap(raw);
    if (response.coachingMessage.isEmpty) return null;
    return response;
  }
}
