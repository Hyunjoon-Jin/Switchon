import 'package:flutter_test/flutter_test.dart';
import 'package:switchon/core/program/branch_engine.dart';

void main() {
  test('분기 주차는 3주차 이상', () {
    expect(BranchEngine.isBranchWeek(2), false);
    expect(BranchEngine.isBranchWeek(3), true);
    expect(BranchEngine.isBranchWeek(4), true);
  });

  test('근육 미회복 → 반복', () {
    final r = BranchEngine.evaluate(
      const BranchAnswers(muscleRecovered: false, reachedGoal: false),
    );
    expect(r.result, BranchResult.repeat);
  });

  test('근육 회복 + 목표 미달 → 진행', () {
    final r = BranchEngine.evaluate(
      const BranchAnswers(muscleRecovered: true, reachedGoal: false),
    );
    expect(r.result, BranchResult.advance);
  });

  test('근육 회복 + 목표 달성 → 유지', () {
    final r = BranchEngine.evaluate(
      const BranchAnswers(muscleRecovered: true, reachedGoal: true),
    );
    expect(r.result, BranchResult.maintain);
  });

  test('DB 직렬화/역직렬화', () {
    expect(BranchResult.repeat.db, 'repeat');
    expect(BranchResultDb.fromDb('maintain'), BranchResult.maintain);
    expect(BranchResultDb.fromDb(null), isNull);
  });
}
