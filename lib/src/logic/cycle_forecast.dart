import 'dart:math' as math;

import '../models/cycle_settings.dart';
import '../models/period_record.dart';
import '../utils/dates.dart';

/// The rules of thumb behind every prediction.
abstract final class CycleRules {
  /// A gap between two period starts outside this range is treated as a gap
  /// in the records (a missed entry, say) rather than as a real cycle.
  static const minCycle = 15;
  static const maxCycle = 60;

  /// Longest period accepted, and how long an open one counts as ongoing.
  static const maxPeriod = 15;

  /// How many of the latest cycles and periods feed the averages.
  static const sampleSize = 6;

  /// With three or more samples, ones this far from the median are ignored.
  static const outlierDays = 10;

  /// Ovulation comes about 14 days before the next period; this second half
  /// of the cycle varies far less than the first.
  static const lutealDays = 14;

  /// The fertile window: five days before ovulation to four days after.
  static const fertileBefore = 5;
  static const fertileAfter = 4;

  /// The last days of a cycle, when premenstrual symptoms are most likely.
  static const premenstrualDays = 5;
}

/// Where today falls in her cycle.
enum CyclePhase {
  none,
  period,
  follicular,
  fertile,
  ovulation,
  luteal,
  premenstrual,
  late,

  /// Late by more than a whole cycle, which usually means periods went
  /// unrecorded; predictions wait until the records catch up.
  stale,
}

/// How a calendar day is marked.
enum DayKind { none, period, predictedPeriod, fertile, ovulation }

/// Everything the app shows about her cycle, derived from the records as of
/// [today]. Pure and cheap, so it is simply recomputed after every change.
class CycleForecast {
  CycleForecast._({
    required this.today,
    required this.records,
    required this.cycleLength,
    required this.periodLength,
    required this.cycleSamples,
    required this.periodSamples,
    this.current,
    this.inPeriod = false,
    this.nextStart,
    this.projectionStart,
    this.phase = CyclePhase.none,
  });

  factory CycleForecast.compute({
    required List<PeriodRecord> records,
    required CycleSettings settings,
    required DateTime today,
  }) {
    final day = dateOnly(today);
    final sorted = [...records]..sort((a, b) => a.start.compareTo(b.start));
    final history = [
      for (final record in sorted)
        if (!record.start.isAfter(day)) record,
    ];

    final cycles = recentCycleLengths(history);
    final cycleLength = cycles.isEmpty
        ? settings.cycleLength
        : robustAverage(cycles);
    final periods = recentPeriodLengths(history);
    final periodLength = math.min(
      periods.isEmpty ? settings.periodLength : robustAverage(periods),
      cycleLength - 1,
    );

    final current = history.isEmpty ? null : history.last;
    if (current == null) {
      return CycleForecast._(
        today: day,
        records: sorted,
        cycleLength: cycleLength,
        periodLength: periodLength,
        cycleSamples: cycles.length,
        periodSamples: periods.length,
      );
    }

    final end = current.end;
    final inPeriod = end != null
        ? !day.isAfter(end)
        : daysBetween(current.start, day) < CycleRules.maxPeriod;
    final nextStart = addDays(current.start, cycleLength);
    final stale = !inPeriod && daysBetween(nextStart, day) > cycleLength;

    return CycleForecast._(
      today: day,
      records: sorted,
      cycleLength: cycleLength,
      periodLength: periodLength,
      cycleSamples: cycles.length,
      periodSamples: periods.length,
      current: current,
      inPeriod: inPeriod,
      nextStart: nextStart,
      // Once she is late, expect the period any day now, not in the past.
      projectionStart: stale
          ? null
          : day.isAfter(nextStart)
          ? day
          : nextStart,
      phase: stale
          ? CyclePhase.stale
          : _phaseOn(day, inPeriod: inPeriod, nextStart: nextStart),
    );
  }

  /// The day everything is relative to.
  final DateTime today;

  /// Every record, oldest first.
  final List<PeriodRecord> records;

  /// Cycle and period lengths used for predictions, in days.
  final int cycleLength;
  final int periodLength;

  /// How many recorded cycles and periods those lengths come from; zero
  /// means the defaults from settings were used.
  final int cycleSamples;
  final int periodSamples;

  /// The latest period that has started.
  final PeriodRecord? current;

  /// Whether today falls within [current].
  final bool inPeriod;

  /// When the next period is expected, counted from [current].
  final DateTime? nextStart;

  /// Start of the predicted periods ahead: [nextStart], or today once she is
  /// late. Null when there is no data, or the data is too stale to project.
  final DateTime? projectionStart;

  final CyclePhase phase;

  bool get hasData => current != null;

  /// Whether she is in a period whose end has not been recorded yet.
  bool get isOngoing => inPeriod && current!.end == null;

  /// 1-based day of the current period.
  int? get periodDay =>
      inPeriod ? daysBetween(current!.start, today) + 1 : null;

  /// 1-based day of the current cycle.
  int? get cycleDay =>
      current == null ? null : daysBetween(current!.start, today) + 1;

  /// Days until [nextStart]; negative once she is late.
  int? get daysUntilNext =>
      nextStart == null ? null : daysBetween(today, nextStart!);

  bool get isLate => phase == CyclePhase.late;

  int get lateDays => isLate ? -daysUntilNext! : 0;

  bool get isStale => phase == CyclePhase.stale;

  /// When the current period should end, going by the average length.
  DateTime? get expectedPeriodEnd =>
      current == null ? null : addDays(current!.start, periodLength - 1);

  /// Ovulation day of the fertile window that is under way or comes next.
  DateTime? get upcomingOvulation {
    final next = nextStart;
    if (next == null) return null;
    final thisCycle = addDays(next, -CycleRules.lutealDays);
    if (!addDays(thisCycle, CycleRules.fertileAfter).isBefore(today)) {
      return thisCycle;
    }
    final projection = projectionStart;
    if (projection == null) return null;
    return addDays(projection, cycleLength - CycleRules.lutealDays);
  }

  /// The fertile window around [upcomingOvulation].
  DateSpan? get fertileWindow {
    final ovulation = upcomingOvulation;
    if (ovulation == null) return null;
    return (
      start: addDays(ovulation, -CycleRules.fertileBefore),
      end: addDays(ovulation, CycleRules.fertileAfter),
    );
  }

  /// The next [count] predicted periods, soonest first.
  List<DateSpan> upcomingPeriods(int count) {
    final first = projectionStart;
    if (first == null) return const [];
    return [
      for (var i = 0; i < count; i++)
        (
          start: addDays(first, i * cycleLength),
          end: addDays(first, i * cycleLength + periodLength - 1),
        ),
    ];
  }

  /// The record whose period covers [date], if any.
  PeriodRecord? recordOn(DateTime date) {
    final day = dateOnly(date);
    for (final record in records) {
      if (day.isBefore(record.start)) break;
      if (!day.isAfter(lastDayOf(record))) return record;
    }
    return null;
  }

  /// Last day [record] covers: its recorded end, or else an estimate from the
  /// average length. An ongoing period covers at least up to today.
  DateTime lastDayOf(PeriodRecord record) {
    if (record.end case final end?) return end;
    final estimate = addDays(record.start, periodLength - 1);
    final ongoing = isOngoing && record.id == current!.id;
    return ongoing && estimate.isBefore(today) ? today : estimate;
  }

  /// How [date] should be marked on the calendar.
  DayKind kindOf(DateTime date) {
    final day = dateOnly(date);
    final record = recordOn(day);
    if (record != null) {
      // The rest of an ongoing period is still only expected.
      final expected =
          isOngoing && record.id == current!.id && day.isAfter(today);
      return expected ? DayKind.predictedPeriod : DayKind.period;
    }

    final latest = current;
    if (latest == null || !day.isAfter(latest.start)) return DayKind.none;
    final projection = projectionStart;
    if (projection == null || day.isBefore(projection)) {
      final ovulation = addDays(nextStart!, -CycleRules.lutealDays);
      return _fertileKind(daysBetween(ovulation, day));
    }
    final offset = daysBetween(projection, day) % cycleLength;
    if (offset < periodLength) return DayKind.predictedPeriod;
    return _fertileKind(offset - (cycleLength - CycleRules.lutealDays));
  }

  /// What the cycle dial draws for the current cycle.
  DialData get dial {
    final current = this.current;
    if (current == null) {
      return DialData(length: cycleLength, periodDays: periodLength);
    }
    final dayIndex = daysBetween(current.start, today);
    final periodDays =
        current.length ??
        (isOngoing ? math.max(periodLength, dayIndex + 1) : periodLength);
    return DialData(
      length: cycleLength,
      periodDays: math.min(periodDays, cycleLength),
      todayIndex: math.min(dayIndex, cycleLength),
      inPeriod: inPeriod,
    );
  }

  static CyclePhase _phaseOn(
    DateTime day, {
    required bool inPeriod,
    required DateTime nextStart,
  }) {
    if (inPeriod) return CyclePhase.period;
    final daysUntilNext = daysBetween(day, nextStart);
    if (daysUntilNext < 0) return CyclePhase.late;
    final ovulation = addDays(nextStart, -CycleRules.lutealDays);
    return switch (_fertileKind(daysBetween(ovulation, day))) {
      DayKind.ovulation => CyclePhase.ovulation,
      DayKind.fertile => CyclePhase.fertile,
      _ when day.isBefore(ovulation) => CyclePhase.follicular,
      _ when daysUntilNext <= CycleRules.premenstrualDays =>
        CyclePhase.premenstrual,
      _ => CyclePhase.luteal,
    };
  }

  static DayKind _fertileKind(int daysFromOvulation) {
    if (daysFromOvulation == 0) return DayKind.ovulation;
    if (daysFromOvulation >= -CycleRules.fertileBefore &&
        daysFromOvulation <= CycleRules.fertileAfter) {
      return DayKind.fertile;
    }
    return DayKind.none;
  }
}

/// The current cycle as the dial draws it: one bead per day, day 1 at the top.
class DialData {
  const DialData({
    required this.length,
    required this.periodDays,
    this.todayIndex,
    this.inPeriod = false,
  });

  final int length;

  /// How many leading days are period days.
  final int periodDays;

  /// 0-based position of today; equals [length] once the next period is
  /// due. Null when nothing has been recorded yet.
  final int? todayIndex;

  final bool inPeriod;

  int get ovulationIndex => length - CycleRules.lutealDays;

  DayKind kindAt(int index) {
    if (index < periodDays) return DayKind.period;
    return CycleForecast._fertileKind(index - ovulationIndex);
  }

  @override
  bool operator ==(Object other) =>
      other is DialData &&
      other.length == length &&
      other.periodDays == periodDays &&
      other.todayIndex == todayIndex &&
      other.inPeriod == inPeriod;

  @override
  int get hashCode => Object.hash(length, periodDays, todayIndex, inPeriod);
}

/// Gaps between consecutive period starts that look like real cycles, latest
/// last, at most [CycleRules.sampleSize] of them.
List<int> recentCycleLengths(List<PeriodRecord> sorted) => _takeLast([
  for (var i = 1; i < sorted.length; i++)
    if (daysBetween(sorted[i - 1].start, sorted[i].start) case final gap
        when gap >= CycleRules.minCycle && gap <= CycleRules.maxCycle)
      gap,
]);

/// Lengths of recent periods with a plausible recorded end, latest last.
List<int> recentPeriodLengths(List<PeriodRecord> sorted) => _takeLast([
  for (final record in sorted)
    if (record.length case final length?
        when length >= 1 && length <= CycleRules.maxPeriod)
      length,
]);

/// Rounded mean that, once there are enough samples to tell what is typical,
/// ignores the ones far from the median.
int robustAverage(List<int> samples) {
  var kept = samples;
  if (samples.length >= 3) {
    final sorted = [...samples]..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2;
    final typical = [
      for (final sample in samples)
        if ((sample - median).abs() <= CycleRules.outlierDays) sample,
    ];
    if (typical.isNotEmpty) kept = typical;
  }
  return (kept.reduce((a, b) => a + b) / kept.length).round();
}

List<int> _takeLast(List<int> values) => values.length <= CycleRules.sampleSize
    ? values
    : values.sublist(values.length - CycleRules.sampleSize);
