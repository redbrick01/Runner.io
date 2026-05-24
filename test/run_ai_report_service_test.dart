import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/services/run_ai_report_service.dart';

void main() {
  group('RunAiReport', () {
    test('parses structured report response', () {
      final report = RunAiReport.fromMap({
        'run_id': 42,
        'summary': '오늘은 후반 페이스가 좋아졌어요.',
        'improvements': ['초반 페이스를 조금 낮춰 보세요.', '상승 구간 후 회복을 챙기세요.'],
        'next_goal': {
          'type': 'pace',
          'label': '다음 5km 평균 페이스 5초 단축',
          'target_pace_s_per_km': 355,
        },
        'coaching_message': '좋은 리듬이에요.',
        'comparison': {'similar_run_count': 4},
        'status': 'completed',
        'model': 'gpt-5.4-mini',
        'created_at': '2026-05-24T12:00:00Z',
      });

      expect(report.runId, 42);
      expect(report.isCompleted, isTrue);
      expect(report.similarRunCount, 4);
      expect(report.nextGoalLabel, '다음 5km 평균 페이스 5초 단축');
      expect(report.improvements, hasLength(2));
      expect(report.model, 'gpt-5.4-mini');
    });

    test('falls back when optional structured fields are missing', () {
      final report = RunAiReport.fromMap({
        'run_id': '7',
        'summary': '기록이 부족해요.',
        'status': 'insufficient_data',
      });

      expect(report.runId, 7);
      expect(report.isInsufficientData, isTrue);
      expect(report.similarRunCount, 0);
      expect(report.nextGoalLabel, contains('일정한 페이스'));
      expect(report.improvements, isEmpty);
    });
  });
}
