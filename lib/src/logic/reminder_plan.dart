import '../models/reminder_settings.dart';
import '../utils/dates.dart';
import 'cycle_forecast.dart';

enum ReminderKind {
  /// Some days before the predicted start, to get ready.
  early,

  /// On the predicted day, which doubles as a nudge to record it.
  due,
}

/// A notification that should be scheduled.
class PlannedReminder {
  const PlannedReminder({
    required this.kind,
    required this.periodStart,
    required this.time,
    required this.title,
    required this.body,
  });

  final ReminderKind kind;

  /// The predicted start the reminder is about.
  final DateTime periodStart;

  /// When it goes off, in local time.
  final DateTime time;

  final String title;
  final String body;

  /// Notification id, unique to the kind and the predicted day: 202610032 is
  /// the due-day reminder for a period expected on 3 October 2026.
  int get id =>
      (periodStart.year * 10000 + periodStart.month * 100 + periodStart.day) *
          10 +
      kind.index +
      1;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.kind == kind &&
      other.periodStart == periodStart &&
      other.time == time &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(kind, periodStart, time, title, body);
}

/// The reminders to have scheduled as of [now], soonest first: one
/// [ReminderSettings.daysBefore] days before the next predicted period and
/// one on the day itself, leaving out any whose time has passed.
///
/// Only the next period is covered. Recording it moves the prediction on,
/// which plans the one after. While she is late, or the records have gone
/// stale, the app has no date to count down to, so nothing is planned until
/// the records catch up.
List<PlannedReminder> planReminders({
  required CycleForecast forecast,
  required ReminderSettings settings,
  required String name,
  required DateTime now,
}) {
  final start = forecast.nextStart;
  if (!settings.enabled ||
      start == null ||
      forecast.isLate ||
      forecast.isStale) {
    return const [];
  }

  DateTime at(DateTime day) =>
      DateTime(day.year, day.month, day.day, settings.hour, settings.minute);
  final days = settings.daysBefore;
  final reminders = [
    PlannedReminder(
      kind: ReminderKind.early,
      periodStart: start,
      time: at(addDays(start, -days)),
      title: days == 1 ? '$name的月经预计明天来' : '$name的月经预计 $days 天后来',
      body:
          '预计 ${formatMonthDayWeekday(start)} 开始。'
          '提前备好卫生用品和热水袋，这几天多体贴$name一点。',
    ),
    PlannedReminder(
      kind: ReminderKind.due,
      periodStart: start,
      time: at(start),
      title: '$name的月经预计今天来',
      body: '来了的话，打开 LunaCare 点“$name今天来月经了”，之后的预测会更准。',
    ),
  ];
  return [
    for (final reminder in reminders)
      if (reminder.time.isAfter(now)) reminder,
  ];
}
