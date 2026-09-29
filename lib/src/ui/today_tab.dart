import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/cycle_forecast.dart';
import '../models/period_record.dart';
import '../state/cycle_scope.dart';
import '../theme.dart';
import '../utils/dates.dart';
import 'phase_copy.dart';
import 'record_editor.dart';
import 'widgets/cycle_dial.dart';
import 'widgets/day_count.dart';

class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CycleScope.of(context);
    final forecast = store.forecast;
    final name = store.settings.displayName;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = math.max(24.0, (constraints.maxWidth - 480) / 2);
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: CycleDial(dial: forecast.dial),
              ),
            ),
            const SizedBox(height: 12),
            _Headline(forecast: forecast, name: name),
            const SizedBox(height: 24),
            _Actions(forecast: forecast, name: name),
            if (forecast.hasData) ...[
              const SizedBox(height: 36),
              _PhaseNote(phase: forecast.phase, name: name),
              const SizedBox(height: 20),
              _Facts(forecast: forecast),
            ],
            const SizedBox(height: 24),
            Text(
              '预测根据过往记录推算，仅供参考，不能用于避孕。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.forecast, required this.name});

  final CycleForecast forecast;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = forecast;
    final Widget title;
    final String caption;
    if (!f.hasData) {
      title = const _TitleText('还没有记录');
      caption = '记下$name最近一次来月经的日期，就能推算下一次。';
    } else if (f.inPeriod) {
      title = _CountTitle(
        before: '经期第',
        count: f.periodDay!,
        after: '天',
        color: CycleColors.of(context).period,
      );
      caption = _periodCaption(f);
    } else if (f.isStale) {
      title = const _TitleText('很久没有新记录了');
      caption = '上次记录是 ${formatFullDate(f.current!.start)}。补上最近一次月经，预测会重新计算。';
    } else if (f.isLate) {
      title = _CountTitle(before: '推迟了', count: f.lateDays, after: '天');
      caption = '原本预计 ${formatMonthDayWeekday(f.nextStart!)} 来';
    } else if (f.daysUntilNext == 0) {
      title = const _TitleText('预计今天来月经');
      caption = '来了的话，点下面的按钮记一下。';
    } else {
      title = _CountTitle(before: '还有', count: f.daysUntilNext!, after: '天');
      caption = '下次月经预计 ${formatMonthDayWeekday(f.nextStart!)}';
    }

    return Column(
      children: [
        title,
        const SizedBox(height: 8),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  static String _periodCaption(CycleForecast f) {
    if (f.current!.end != null) return '今天是这次月经的最后一天';
    final end = f.expectedPeriodEnd!;
    final left = daysBetween(f.today, end);
    if (left > 0) {
      return '一般持续 ${f.periodLength} 天，预计 ${formatMonthDayWeekday(end)} 结束';
    }
    if (left == 0) return '按往常，今天就会结束';
    return '比平时多了 ${-left} 天，结束那天记得点下面的按钮';
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w600),
  );
}

/// "还有 12 天", with the count set large in the display face.
class _CountTitle extends StatelessWidget {
  const _CountTitle({
    required this.before,
    required this.count,
    required this.after,
    this.color,
  });

  final String before;
  final int count;
  final String after;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final words = Theme.of(context).textTheme.titleLarge;
    return MergeSemantics(
      // Shrinks rather than overflows with very large system fonts.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(before, style: words),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$count',
                style: numeralStyle(
                  context,
                  76,
                  color: color,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            Text(after, style: words),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.forecast, required this.name});

  final CycleForecast forecast;
  final String name;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    Widget? primary;
    Widget? secondary;
    if (!f.hasData) {
      primary = FilledButton(
        onPressed: () => showRecordEditor(context, initialStart: f.today),
        child: const Text('记录最近一次月经'),
      );
    } else if (f.isOngoing) {
      primary = FilledButton.tonal(
        onPressed: () => endPeriodOn(context, f.current!, f.today),
        child: const Text('月经今天结束了'),
      );
      secondary = TextButton(
        onPressed: () => _pickEnd(context, f.current!),
        child: const Text('选择其他结束日期'),
      );
    } else if (f.inPeriod) {
      secondary = TextButton(
        onPressed: () => showRecordEditor(context, record: f.current),
        child: const Text('修改这次记录'),
      );
    } else {
      primary = FilledButton(
        onPressed: () => startPeriodOn(context, f.today),
        child: Text('$name今天来月经了'),
      );
      secondary = TextButton(
        onPressed: () => showRecordEditor(context, initialStart: f.today),
        child: const Text('选择其他日期'),
      );
    }

    return Column(
      children: [
        if (primary != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: SizedBox(width: double.infinity, child: primary),
          ),
        if (secondary != null)
          Padding(
            padding: EdgeInsets.only(top: primary == null ? 0 : 4),
            child: secondary,
          ),
      ],
    );
  }

  static Future<void> _pickEnd(
    BuildContext context,
    PeriodRecord record,
  ) async {
    final today = todayDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: record.start,
      lastDate: today,
      helpText: '哪天结束的？',
    );
    if (picked == null || !context.mounted) return;
    await endPeriodOn(context, record, picked);
  }
}

class _PhaseNote extends StatelessWidget {
  const _PhaseNote({required this.phase, required this.name});

  final CyclePhase phase;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = CycleColors.of(context);
    final marker = switch (phase) {
      CyclePhase.period ||
      CyclePhase.premenstrual ||
      CyclePhase.late => colors.period,
      CyclePhase.fertile || CyclePhase.ovulation => colors.ovulation,
      _ => colors.track,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: marker, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              phase.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          phase.tip(name),
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
        ),
      ],
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.forecast});

  final CycleForecast forecast;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    final rows = [
      // Stale records give nothing to predict from; the headline asks for
      // the missing periods instead.
      if (!f.isStale)
        _FactRow(
          label: '下次月经',
          value: Text(f.isLate ? '随时可能来' : formatMonthDayWeekday(f.nextStart!)),
        ),
      if (f.upcomingOvulation case final ovulation?)
        _FactRow(label: '排卵日', value: Text(formatMonthDayWeekday(ovulation))),
      if (f.fertileWindow case final window?)
        _FactRow(
          label: '排卵期',
          value: Text(formatSpan(window.start, window.end)),
        ),
      _FactRow(
        label: '平均周期',
        note: f.cycleSamples == 0
            ? '默认值，记下两次间隔正常的月经后按实际计算'
            : '根据最近 ${f.cycleSamples} 个周期',
        value: DayCount(f.cycleLength),
      ),
      _FactRow(
        label: '平均经期',
        note: f.periodSamples == 0
            ? '默认值，记下结束日期后按实际计算'
            : '根据最近 ${f.periodSamples} 次记录',
        value: DayCount(f.periodLength),
      ),
    ];
    return Column(
      children: [
        const Divider(),
        for (final row in rows) ...[row, const Divider()],
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value, this.note});

  final String label;
  final Widget value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyLarge),
                  if (note case final note?)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // A value keeps its natural width, but wraps rather than
            // overflowing when large system text makes it too wide.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.end,
                child: value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
