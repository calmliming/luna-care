import '../logic/cycle_forecast.dart';

extension CyclePhaseCopy on CyclePhase {
  String get title => switch (this) {
    CyclePhase.none => '',
    CyclePhase.period => '经期',
    CyclePhase.follicular => '卵泡期',
    CyclePhase.fertile => '排卵期',
    CyclePhase.ovulation => '排卵日',
    CyclePhase.luteal => '黄体期',
    CyclePhase.premenstrual => '经前期',
    CyclePhase.late => '推迟中',
    CyclePhase.stale => '可能漏记了',
  };

  /// How to look after her during this phase; [name] is what she's called.
  String tip(String name) => switch (this) {
    CyclePhase.none => '',
    CyclePhase.period => '$name可能会腹痛、怕冷、容易累。备好热水袋和热饮，少安排累人的行程，多一点耐心。',
    CyclePhase.follicular => '经期刚过，$name的精力和心情通常比较好，适合约会或出去走走。',
    CyclePhase.fertile => '排卵期前后更容易怀孕。没有备孕计划的话，记得做好安全措施。',
    CyclePhase.ovulation => '今天是预测的排卵日，最容易怀孕。没有备孕计划的话，记得做好安全措施。',
    CyclePhase.luteal => '排卵后激素变化，$name可能更容易累，情绪起伏也大一些，多陪陪她。',
    CyclePhase.premenstrual => '月经快来了，$name可能会烦躁、胸胀或者特别想吃东西。提前备好卫生用品，多一点包容。',
    CyclePhase.late => '推迟几天很常见，压力、熬夜、换环境都会影响。推迟超过一周的话，可以提醒$name留意一下身体。',
    CyclePhase.stale => '如果这段时间来过月经，到“记录”里补上日期，预测就会恢复。如果确实一直没来，建议提醒$name去医院看看。',
  };
}

extension DayKindCopy on DayKind {
  String? get label => switch (this) {
    DayKind.none => null,
    DayKind.period => '经期',
    DayKind.predictedPeriod => '预测经期',
    DayKind.fertile => '预测排卵期',
    DayKind.ovulation => '预测排卵日',
  };
}
