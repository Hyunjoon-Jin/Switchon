import 'package:flutter_test/flutter_test.dart';
import 'package:switchon/core/program/stage_engine.dart';

void main() {
  final start = DateTime(2026, 6, 1);

  group('StageEngine.compute', () {
    test('시작일 당일은 1주차 1일차', () {
      final p = StageEngine.compute(
        startDate: start,
        status: 'active',
        today: DateTime(2026, 6, 1),
      );
      expect(p.week, 1);
      expect(p.day, 1);
      expect(p.programDay, 1);
      expect(p.isCompleted, false);
    });

    test('7일 경과 → 2주차 1일차, 전체 8일차', () {
      final p = StageEngine.compute(
        startDate: start,
        status: 'active',
        today: DateTime(2026, 6, 8),
      );
      expect(p.week, 2);
      expect(p.day, 1);
      expect(p.programDay, 8);
    });

    test('일시정지 중에는 멈춘 날에 위치 고정', () {
      final p = StageEngine.compute(
        startDate: start,
        status: 'paused',
        pausedAt: DateTime(2026, 6, 3),
        today: DateTime(2026, 6, 10),
      );
      expect(p.isPaused, true);
      expect(p.week, 1);
      expect(p.day, 3); // 멈춘 시점(3일차) 유지
      expect(p.programDay, 3);
    });

    test('28일 초과 → 완료, 마지막 일차에 고정', () {
      final p = StageEngine.compute(
        startDate: start,
        status: 'active',
        today: DateTime(2026, 7, 10), // 39일 경과
      );
      expect(p.isCompleted, true);
      expect(p.programDay, 28);
      expect(p.week, 4);
      expect(p.day, 7);
    });
  });

  group('StageEngine.resumedStartDate', () {
    test('멈춰 있던 7일만큼 시작일을 뒤로 민다 → 멈춘 일차에서 재개', () {
      final pausedAt = DateTime(2026, 6, 3);
      final today = DateTime(2026, 6, 10); // 7일 멈춤
      final newStart = StageEngine.resumedStartDate(
        startDate: start,
        pausedAt: pausedAt,
        today: today,
      );
      expect(newStart, DateTime(2026, 6, 8));

      // 재개 직후 위치는 멈췄던 3일차 그대로여야 한다.
      final p = StageEngine.compute(
        startDate: newStart,
        status: 'active',
        today: today,
      );
      expect(p.programDay, 3);
      expect(p.day, 3);
    });
  });
}
