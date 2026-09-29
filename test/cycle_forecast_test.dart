import 'package:flutter_test/flutter_test.dart';
import 'package:luna_care/src/logic/cycle_forecast.dart';
import 'package:luna_care/src/models/cycle_settings.dart';
import 'package:luna_care/src/models/period_record.dart';
import 'package:luna_care/src/utils/dates.dart';

final today = DateTime(2026, 9, 29);

/// A period that started [daysAgo] days before [today].
PeriodRecord period(int daysAgo, {int? length}) {
  final start = addDays(today, -daysAgo);
  return PeriodRecord(
    id: 'r$daysAgo',
    start: start,
    end: length == null ? null : addDays(start, length - 1),
  );
}

CycleForecast forecastOf(
  List<PeriodRecord> records, {
  CycleSettings settings = const CycleSettings(),
}) => CycleForecast.compute(records: records, settings: settings, today: today);

void main() {
  group('averages', () {
    test('fall back to the settings without history', () {
      final f = forecastOf(
        [],
        settings: const CycleSettings(cycleLength: 30, periodLength: 6),
      );
      expect(f.hasData, isFalse);
      expect(f.phase, CyclePhase.none);
      expect(f.cycleLength, 30);
      expect(f.periodLength, 6);
      expect(f.cycleSamples, 0);
      expect(f.nextStart, isNull);
    });

    test('come from recent cycles and recorded period lengths', () {
      final f = forecastOf([
        period(70, length: 5),
        period(40, length: 6),
        period(10, length: 7),
      ]);
      expect(f.cycleLength, 30);
      expect(f.cycleSamples, 2);
      expect(f.periodLength, 6);
      expect(f.nextStart, addDays(today, 20));
      expect(f.daysUntilNext, 20);
    });

    test('ignore a month with a missed record', () {
      // Gaps of 28, 56, 29 and 28 days: the 56 is two cycles run together.
      final f = forecastOf([
        for (final daysAgo in [143, 115, 59, 30, 2]) period(daysAgo, length: 5),
      ]);
      expect(f.cycleLength, 28);
    });

    test('skip gaps too long to be one cycle', () {
      final f = forecastOf([period(100, length: 5), period(30, length: 5)]);
      expect(f.cycleSamples, 0);
      expect(f.cycleLength, CycleSettings.defaultCycleLength);
    });

    test('use only the latest six cycles', () {
      final starts = [
        for (var i = 0; i < 6; i++) 400 - i * 40, // six old 40-day cycles
        for (var i = 0; i < 7; i++) 180 - i * 30, // then 30-day cycles
      ];
      final f = forecastOf([for (final d in starts) period(d, length: 5)]);
      expect(f.cycleSamples, 6);
      expect(f.cycleLength, 30);
    });
  });

  group('today', () {
    test('an open period is ongoing', () {
      final f = forecastOf([period(40, length: 5), period(2)]);
      expect(f.inPeriod, isTrue);
      expect(f.isOngoing, isTrue);
      expect(f.periodDay, 3);
      expect(f.phase, CyclePhase.period);
      expect(f.dial.todayIndex, 2);
      expect(f.dial.inPeriod, isTrue);
    });

    test('an open period stops counting as ongoing after 15 days', () {
      final f = forecastOf([period(20)]);
      expect(f.inPeriod, isFalse);
      expect(f.phase, CyclePhase.luteal);
    });

    test('she is late once the expected day has passed', () {
      final f = forecastOf([period(33, length: 5)]);
      expect(f.isLate, isTrue);
      expect(f.lateDays, 5);
      expect(f.isStale, isFalse);
      expect(f.projectionStart, today);
      expect(f.kindOf(today), DayKind.predictedPeriod);
      expect(f.dial.todayIndex, 28);
    });

    test('a very long silence reads as missing records', () {
      final f = forecastOf([period(90, length: 5)]);
      expect(f.isStale, isTrue);
      expect(f.isLate, isFalse);
      expect(f.phase, CyclePhase.stale);
      // Nothing is projected from records that are clearly incomplete.
      expect(f.projectionStart, isNull);
      expect(f.upcomingPeriods(3), isEmpty);
      expect(f.upcomingOvulation, isNull);
      expect(f.kindOf(today), DayKind.none);
    });

    test('phases follow the cycle', () {
      // 28-day cycle: ovulation on day 15, fertile window days 10 to 19.
      CyclePhase phaseOnDay(int day) =>
          forecastOf([period(day - 1, length: 5)]).phase;
      expect(phaseOnDay(3), CyclePhase.period);
      expect(phaseOnDay(9), CyclePhase.follicular);
      expect(phaseOnDay(10), CyclePhase.fertile);
      expect(phaseOnDay(15), CyclePhase.ovulation);
      expect(phaseOnDay(19), CyclePhase.fertile);
      expect(phaseOnDay(20), CyclePhase.luteal);
      expect(phaseOnDay(24), CyclePhase.premenstrual);
      expect(phaseOnDay(28), CyclePhase.premenstrual);
    });
  });

  group('calendar', () {
    test('marks recorded, fertile and predicted days', () {
      // Started 9/19 and lasted 5 days; next period due 10/17.
      final f = forecastOf([period(10, length: 5)]);
      DayKind on(int month, int day) => f.kindOf(DateTime(2026, month, day));
      expect(on(9, 18), DayKind.none);
      expect(on(9, 19), DayKind.period);
      expect(on(9, 23), DayKind.period);
      expect(on(9, 24), DayKind.none);
      expect(on(9, 27), DayKind.none);
      expect(on(9, 28), DayKind.fertile);
      expect(on(10, 3), DayKind.ovulation);
      expect(on(10, 7), DayKind.fertile);
      expect(on(10, 8), DayKind.none);
      expect(on(10, 17), DayKind.predictedPeriod);
      expect(on(10, 21), DayKind.predictedPeriod);
      expect(on(10, 22), DayKind.none);
      // One cycle further on.
      expect(on(10, 31), DayKind.ovulation);
      expect(on(11, 14), DayKind.predictedPeriod);
    });

    test('shows the rest of an ongoing period as expected', () {
      final f = forecastOf([period(1)]);
      expect(f.kindOf(DateTime(2026, 9, 28)), DayKind.period);
      expect(f.kindOf(today), DayKind.period);
      expect(f.kindOf(DateTime(2026, 9, 30)), DayKind.predictedPeriod);
      expect(f.kindOf(DateTime(2026, 10, 2)), DayKind.predictedPeriod);
      expect(f.kindOf(DateTime(2026, 10, 3)), DayKind.none);
      expect(f.recordOn(DateTime(2026, 9, 28))?.id, 'r1');
    });

    test('lists the next predicted periods', () {
      final f = forecastOf([period(10, length: 5)]);
      expect(f.upcomingPeriods(2), [
        (start: DateTime(2026, 10, 17), end: DateTime(2026, 10, 21)),
        (start: DateTime(2026, 11, 14), end: DateTime(2026, 11, 18)),
      ]);
      expect(forecastOf([]).upcomingPeriods(3), isEmpty);
    });

    test('moves on to the next fertile window once one has passed', () {
      final f = forecastOf([period(22, length: 5)]);
      expect(f.upcomingOvulation, DateTime(2026, 10, 19));
      expect(f.fertileWindow, (
        start: DateTime(2026, 10, 14),
        end: DateTime(2026, 10, 23),
      ));
    });
  });

  test('a period ending before it starts does not count', () {
    final backwards = PeriodRecord(
      id: 'x',
      start: addDays(today, -40),
      end: addDays(today, -50),
    );
    expect(
      forecastOf([backwards]).periodLength,
      CycleSettings.defaultPeriodLength,
    );
  });

  test('robustAverage drops outliers only with enough samples', () {
    expect(robustAverage([28, 56]), 42);
    expect(robustAverage([28, 56, 29, 28]), 28);
    expect(robustAverage([20, 20, 50, 50]), 35);
  });

  test('daysBetween counts calendar days', () {
    expect(daysBetween(DateTime(2026, 2, 27), DateTime(2026, 3, 2)), 3);
    expect(daysBetween(DateTime(2026, 3, 2, 23), DateTime(2026, 3, 1, 1)), -1);
    expect(addDays(DateTime(2026, 12, 30), 3), DateTime(2027, 1, 2));
  });
}
