import 'package:flutter_test/flutter_test.dart';
import 'package:switchon/core/program/diet_rules.dart';

void main() {
  RuleEvaluation eval(String stageId, int week, List<String> tags) =>
      DietRules.evaluate(stageId: stageId, week: week, tagIds: tags);

  group('1주차 셰이크 집중기 (allowOnly)', () {
    test('셰이크는 허용', () {
      final r = eval('w1_shake_only', 1, ['shake']);
      expect(r.isClean, true);
    });
    test('일반식은 위반', () {
      final r = eval('w1_shake_only', 1, ['protein', 'rice']);
      expect(r.isViolation, true);
      expect(r.violations.length, 2);
    });
  });

  group('1주차 점심 추가', () {
    test('단백질은 허용', () {
      expect(eval('w1_lunch_added', 1, ['protein']).isClean, true);
    });
    test('밀가루는 위반', () {
      expect(eval('w1_lunch_added', 1, ['refined_carbs']).isViolation, true);
    });
    test('견과류는 주의(아직 권장 X)', () {
      final r = eval('w1_lunch_added', 1, ['nuts']);
      expect(r.isViolation, false);
      expect(r.hasCaution, true);
    });
  });

  group('2주차', () {
    test('견과류 허용, 당류 위반, 곡물 주의', () {
      final r = eval('w2', 2, ['nuts', 'sugar', 'rice']);
      expect(r.violations.map((t) => t.id), contains('sugar'));
      expect(r.cautions.map((t) => t.id), contains('rice'));
      expect(r.violations.map((t) => t.id), isNot(contains('nuts')));
    });
  });

  group('3~4주차', () {
    test('음주는 위반', () {
      expect(eval('w3_4', 3, ['alcohol']).isViolation, true);
    });
  });

  test('위반 메시지에 주차와 식품명이 포함', () {
    final r = eval('w3_4', 3, ['refined_carbs']);
    expect(r.message, contains('3주차'));
    expect(r.message, contains('밀가루'));
  });

  test('알 수 없는 태그는 무시', () {
    expect(eval('w2', 2, ['unknown_tag']).isClean, true);
  });
}
