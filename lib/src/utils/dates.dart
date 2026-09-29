// Calendar-day helpers. The app reasons in whole days, so every DateTime it
// stores or compares is normalized to local midnight.

/// [value] with the time of day dropped.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Today's local date.
DateTime todayDate() => dateOnly(DateTime.now());

/// [date] moved by [days] calendar days; negative moves back.
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Whole calendar days from [from] to [to]; negative when [to] is earlier.
int daysBetween(DateTime from, DateTime to) {
  // UTC has no daylight-saving jumps, so every day is exactly 24 hours.
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// An inclusive range of days.
typedef DateSpan = ({DateTime start, DateTime end});

/// 2026-09-03, the storage format.
String toIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// 9月3日
String formatMonthDay(DateTime date) => '${date.month}月${date.day}日';

/// 周四
String formatWeekday(DateTime date) => '周${_weekdays[date.weekday - 1]}';

/// 9月3日 周四
String formatMonthDayWeekday(DateTime date) =>
    '${formatMonthDay(date)} ${formatWeekday(date)}';

/// 2026年9月3日
String formatFullDate(DateTime date) => '${date.year}年${formatMonthDay(date)}';

/// 09:00
String formatClock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// 9月3日 周四 09:00
String formatMonthDayWeekdayClock(DateTime time) =>
    '${formatMonthDayWeekday(time)} ${formatClock(time.hour, time.minute)}';

/// 9月3日, with the year only when it isn't the current one.
String formatDay(DateTime date) => date.year == DateTime.now().year
    ? formatMonthDay(date)
    : formatFullDate(date);

/// 9月3日 – 8日, 9月28日 – 10月2日; years appear only when needed.
String formatSpan(DateTime start, DateTime end) {
  if (start.year != end.year) {
    return '${formatFullDate(start)} – ${formatFullDate(end)}';
  }
  final first = formatDay(start);
  if (start.month != end.month) return '$first – ${formatMonthDay(end)}';
  if (start.day != end.day) return '$first – ${end.day}日';
  return first;
}
