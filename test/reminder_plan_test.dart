import 'package:flutter_test/flutter_test.dart';
import 'package:luna_care/src/logic/cycle_forecast.dart';
import 'package:luna_care/src/logic/reminder_plan.dart';
import 'package:luna_care/src/models/cycle_settings.dart';
import 'package:luna_care/src/models/period_record.dart';
import 'package:luna_care/src/models/reminder_settings.dart';
import 'package:luna_care/src/utils/dates.dart';

final today = DateTime(2026, 9, 29); // A Tuesday.

/// A period that started [daysAgo] days before [today].
PeriodRecord period(int daysAgo, {int? length}) {
  final start = addDays(today, -daysAgo);
  return PeriodRecord(
    id: 'r$daysAgo',
    start: start,
    end: length == null ? null : addDays(start, length - 1),
  );
}

/// The plan at [hour] o'clock today, with the default 28-day cycle.
List<PlannedReminder> planAt(
  int hour,
  List<PeriodRecord> records, {
  ReminderSettings settings = const ReminderSettings(enabled: true),
  String name = '她',
}) => planReminders(
  forecast: CycleForecast.compute(
    records: records,
    settings: const CycleSettings(),
    today: today,
  ),
  settings: settings,
  name: name,
  now: DateTime(today.year, today.month, today.day, hour),
);

void main() {
  test('reminds some days before the predicted start and on the day', () {
    // Started 20 days ago, so the next one is expected on 7 October.
    final plan = planAt(12, [period(20, length: 5)]);

    expect(plan.map((r) => r.kind), [ReminderKind.early, ReminderKind.due]);
    expect(plan.map((r) => r.time), [
      DateTime(2026, 10, 5, 9),
      DateTime(2026, 10, 7, 9),
    ]);
    expect(plan.first.title, '她的月经预计 2 天后来');
    expect(plan.first.body, startsWith('预计 10月7日 周三 开始。'));
    expect(plan.last.title, '她的月经预计今天来');
    expect(plan.last.body, contains('点“她今天来月经了”'));
    expect(plan.map((r) => r.id), [202610071, 202610072]);
  });

  test('follows the chosen days, time and name', () {
    final plan = planAt(
      12,
      [period(20, length: 5)],
      settings: const ReminderSettings(
        enabled: true,
        daysBefore: 1,
        minuteOfDay: 20 * 60 + 30,
      ),
      name: '小月',
    );
    expect(plan.map((r) => r.time), [
      DateTime(2026, 10, 6, 20, 30),
      DateTime(2026, 10, 7, 20, 30),
    ]);
    expect(plan.first.title, '小月的月经预计明天来');
    expect(plan.first.body, endsWith('这几天多体贴小月一点。'));
  });

  test('covers the next period while one is under way', () {
    final plan = planAt(12, [period(2)]);
    expect(plan.map((r) => r.periodStart).toSet(), {addDays(today, 26)});
  });

  test('leaves out reminders whose time has passed', () {
    // Expected in two days: the early reminder is due this morning.
    expect(planAt(8, [period(26)]), hasLength(2));
    expect(planAt(10, [period(26)]).map((r) => r.kind), [ReminderKind.due]);

    // Expected today: only the day's own reminder, and only until it fires.
    expect(planAt(8, [period(28)]).map((r) => r.kind), [ReminderKind.due]);
    expect(planAt(10, [period(28)]), isEmpty);
  });

  test('plans nothing when off, without records, late or stale', () {
    expect(
      planAt(12, [period(20)], settings: const ReminderSettings()),
      isEmpty,
    );
    expect(planAt(12, []), isEmpty);
    // Two days late: the app no longer has a date to count down to.
    expect(planAt(12, [period(30)]), isEmpty);
    // Late by more than a whole cycle: predictions are paused.
    expect(planAt(12, [period(70)]), isEmpty);
  });

  test('reminder settings survive a round trip and reject nonsense', () {
    const settings = ReminderSettings(
      enabled: true,
      daysBefore: 3,
      minuteOfDay: 21 * 60 + 15,
    );
    final read = ReminderSettings.fromJson(settings.toJson());
    expect(read.enabled, isTrue);
    expect(read.daysBefore, 3);
    expect((read.hour, read.minute), (21, 15));

    final junk = ReminderSettings.fromJson({
      'enabled': 'yes',
      'daysBefore': 99,
      'minuteOfDay': -5,
    });
    expect(junk.enabled, isFalse);
    expect(junk.daysBefore, ReminderSettings.daysBeforeRange.max);
    expect(junk.minuteOfDay, 0);
    expect(ReminderSettings.fromJson(null).minuteOfDay, 9 * 60);
  });
}
