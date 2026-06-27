import 'package:flutter_test/flutter_test.dart';
import 'package:switchon/core/program/switchon_program.dart';

void main() {
  group('SwitchOnProgram.stageFor', () {
    test('1주차 1~3일은 셰이크 집중기', () {
      expect(SwitchOnProgram.stageFor(1, 1).id, 'w1_shake_only');
      expect(SwitchOnProgram.stageFor(1, 3).id, 'w1_shake_only');
    });

    test('1주차 4~7일은 점심 저탄수 추가', () {
      expect(SwitchOnProgram.stageFor(1, 4).id, 'w1_lunch_added');
      expect(SwitchOnProgram.stageFor(1, 7).id, 'w1_lunch_added');
    });

    test('2주차', () {
      expect(SwitchOnProgram.stageFor(2, 1).id, 'w2');
      expect(SwitchOnProgram.stageFor(2, 7).id, 'w2');
    });

    test('3주차와 4주차는 별도 단계', () {
      expect(SwitchOnProgram.stageFor(3, 1).id, 'w3');
      expect(SwitchOnProgram.stageFor(4, 5).id, 'w4');
    });

    test('모든 단계는 미션·끼니 가이드를 가진다', () {
      for (final s in SwitchOnProgram.stages) {
        expect(s.mission, isNotEmpty, reason: '${s.id} 미션 비어있음');
        expect(s.mealPlan.shake, isNotEmpty, reason: '${s.id} 셰이크 안내 없음');
      }
    });
  });
}
