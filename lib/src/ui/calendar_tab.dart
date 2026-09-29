import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/cycle_forecast.dart';
import '../state/cycle_scope.dart';
import '../theme.dart';
import '../utils/dates.dart';
import 'phase_copy.dart';
import 'record_editor.dart';
import 'widgets/day_count.dart';

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime _month = _monthOf(todayDate());

  /// 1 when paging forward in time and -1 when back; sets the slide direction.
  int _direction = 1;

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  void _showMonth(DateTime month) {
    if (month == _month) return;
    setState(() {
      _direction = month.isAfter(_month) ? 1 : -1;
      _month = month;
    });
  }

  void _step(int months) =>
      _showMonth(DateTime(_month.year, _month.month + months));

  void _showDay(DateTime day) => showModalBottomSheet<void>(
    context: context,
    builder: (_) => _DaySheet(day: day, host: context),
  );

  @override
  Widget build(BuildContext context) {
    final forecast = CycleScope.of(context).forecast;
    final thisMonth = _monthOf(forecast.today);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = math.max(12.0, (constraints.maxWidth - 520) / 2);
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24),
          children: [
            _MonthHeader(
              month: _month,
              onPrevious: () => _step(-1),
              onNext: () => _step(1),
              onThisMonth: _month == thisMonth
                  ? null
                  : () => _showMonth(thisMonth),
            ),
            const SizedBox(height: 4),
            // Day numbers have a fixed-size cell, so they stop growing a
            // little earlier than other text.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: const _WeekdayRow(),
            ),
            const SizedBox(height: 4),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() > 250) _step(velocity < 0 ? 1 : -1);
                },
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) {
                    // The new month slides in from the side it lies on; the
                    // old one leaves the other way.
                    final incoming = child.key == ValueKey(_month);
                    final shift = 0.12 * _direction * (incoming ? 1 : -1);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: Offset(shift, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _MonthGrid(
                    key: ValueKey(_month),
                    month: _month,
                    forecast: forecast,
                    onDayTap: _showDay,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _Legend(),
            if (forecast.upcomingPeriods(3).isNotEmpty) ...[
              const SizedBox(height: 36),
              _Upcoming(
                forecast: forecast,
                onSelect: (day) => _showMonth(_monthOf(day)),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The next few predicted periods, for planning ahead. Tapping one shows its
/// month.
class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.forecast, required this.onSelect});

  final CycleForecast forecast;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '接下来三次月经',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final span in forecast.upcomingPeriods(3))
          InkWell(
            onTap: () => onSelect(span.start),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      formatSpan(span.start, span.end),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    child: _RelativeDays(
                      daysBetween(forecast.today, span.start),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "16 天后", or "今天".
class _RelativeDays extends StatelessWidget {
  const _RelativeDays(this.days);

  final int days;

  @override
  Widget build(BuildContext context) {
    if (days <= 0) return const Text('今天');
    final color = DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        DayCount(days, size: 20, color: color),
        const Text('后'),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onThisMonth,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onThisMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              // Shrinks rather than pushing the buttons off a narrow screen.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${month.month}',
                        style: numeralStyle(
                          context,
                          44,
                          weight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(text: ' 月', style: theme.textTheme.titleMedium),
                      TextSpan(
                        text: '   ${month.year}',
                        style: numeralStyle(
                          context,
                          20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onThisMonth != null)
            TextButton(onPressed: onThisMonth, child: const Text('回到本月')),
          IconButton(
            tooltip: '上个月',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: '下个月',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        for (final name in const ['一', '二', '三', '四', '五', '六', '日'])
          Expanded(
            child: Center(child: Text(name, style: style)),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    super.key,
    required this.month,
    required this.forecast,
    required this.onDayTap,
  });

  final DateTime month;
  final CycleForecast forecast;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = month.weekday - 1; // Weeks start on Monday.
    final kinds = [
      for (var day = 1; day <= days; day++)
        forecast.kindOf(DateTime(month.year, month.month, day)),
    ];
    DayKind? kindOn(int day) => day >= 1 && day <= days ? kinds[day - 1] : null;

    Widget cell(int day, int column) {
      final kind = kindOn(day);
      if (kind == null) return const SizedBox(height: _DayCell.height);
      final date = DateTime(month.year, month.month, day);
      return _DayCell(
        date: date,
        kind: kind,
        joinsPrevious: column > 0 && _sameBand(kind, kindOn(day - 1)),
        joinsNext: column < 6 && _sameBand(kind, kindOn(day + 1)),
        isToday: isSameDay(date, forecast.today),
        onTap: () => onDayTap(date),
      );
    }

    return Column(
      children: [
        for (var week = 0; week * 7 < leading + days; week++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(child: cell(week * 7 + column - leading + 1, column)),
            ],
          ),
      ],
    );
  }

  /// Whether two neighbouring days are drawn as one continuous band.
  static bool _sameBand(DayKind a, DayKind? b) {
    bool fertile(DayKind? kind) =>
        kind == DayKind.fertile || kind == DayKind.ovulation;
    if (a == DayKind.none || b == null) return false;
    return a == b || (fertile(a) && fertile(b));
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.kind,
    required this.joinsPrevious,
    required this.joinsNext,
    required this.isToday,
    required this.onTap,
  });

  static const height = 50.0;

  final DateTime date;
  final DayKind kind;
  final bool joinsPrevious;
  final bool joinsNext;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = CycleColors.of(context);
    final (Color? band, Color text) = switch (kind) {
      DayKind.period => (colors.period, colors.onPeriod),
      DayKind.predictedPeriod => (colors.predicted, colors.period),
      DayKind.fertile => (colors.fertile, theme.colorScheme.onSurface),
      DayKind.ovulation => (colors.fertile, colors.onOvulation),
      DayKind.none => (null, theme.colorScheme.onSurface),
    };
    const round = Radius.circular(17);

    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: [
        formatMonthDayWeekday(date),
        if (isToday) '今天',
        ?kind.label,
      ].join('，'),
      child: SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (band != null)
              // Joined segments overlap by a pixel so no seam shows
              // between days.
              Positioned(
                top: 6,
                bottom: 10,
                left: joinsPrevious ? -0.5 : 3,
                right: joinsNext ? -0.5 : 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: band,
                    borderRadius: BorderRadius.horizontal(
                      left: joinsPrevious ? Radius.zero : round,
                      right: joinsNext ? Radius.zero : round,
                    ),
                  ),
                ),
              ),
            if (kind == DayKind.ovulation)
              Positioned(
                top: 6,
                bottom: 10,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.ovulation,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${date.day}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: text,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (isToday)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.today,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // Ink sits above the bands so a tap on a coloured day still
            // shows its ripple.
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = CycleColors.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
    Widget band(Color color) => Container(
      width: 20,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    Widget dot(Color color, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [
          item(band(colors.period), '经期'),
          item(band(colors.predicted), '预测经期'),
          item(band(colors.fertile), '排卵期'),
          item(dot(colors.ovulation, 12), '排卵日'),
          item(dot(colors.today, 6), '今天'),
        ],
      ),
    );
  }
}

/// What is known about one day, and what can be recorded on it.
class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day, required this.host});

  final DateTime day;

  /// The calendar's context, which outlives this sheet.
  final BuildContext host;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final forecast = CycleScope.of(context).forecast;
    final kind = forecast.kindOf(day);
    final record = forecast.recordOn(day);
    final isFuture = day.isAfter(forecast.today);
    final description = switch (kind) {
      DayKind.period => '经期第 ${daysBetween(record!.start, day) + 1} 天',
      DayKind.predictedPeriod when record != null => '预计还在经期',
      _ => kind.label,
    };

    void then(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    final actions = [
      if (!isFuture && record == null)
        FilledButton(
          onPressed: () =>
              then(() => showRecordEditor(host, initialStart: day)),
          child: const Text('这天来月经了'),
        ),
      if (!isFuture &&
          record != null &&
          record.end == null &&
          !day.isBefore(record.start))
        FilledButton.tonal(
          onPressed: () => then(() => endPeriodOn(host, record, day)),
          child: const Text('设为这次月经的结束日'),
        ),
      if (record != null)
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => then(() => showRecordEditor(host, record: record)),
          child: const Text('编辑这次记录'),
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${formatFullDate(day)} ${formatWeekday(day)}',
              style: theme.textTheme.titleLarge,
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
            ],
            if (isFuture) ...[
              const SizedBox(height: 12),
              Text(
                '这一天还没到，日历上显示的是预测。',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
            if (actions.isNotEmpty) const SizedBox(height: 20),
            for (final action in actions)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: action),
          ],
        ),
      ),
    );
  }
}
