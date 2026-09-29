import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/cycle_forecast.dart';
import '../models/period_record.dart';
import '../state/cycle_scope.dart';
import '../theme.dart';
import '../utils/dates.dart';
import 'record_editor.dart';
import 'widgets/day_count.dart';

/// Every recorded period, newest first, on a timeline whose segments show
/// how many days passed between one period and the next.
class RecordsTab extends StatelessWidget {
  const RecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final forecast = CycleScope.of(context).forecast;
    final records = forecast.records.reversed.toList();
    final theme = Theme.of(context);

    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            '还没有记录。\n点右下角的“补记”，把记得的月经日期加进来，记得越多，预测越准。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = math.max(16.0, (constraints.maxWidth - 520) / 2);
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 96),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final older = index + 1 < records.length
                ? records[index + 1]
                : null;
            return _TimelineEntry(
              record: record,
              forecast: forecast,
              isNewest: index == 0,
              gapFromOlder: older == null
                  ? null
                  : daysBetween(older.start, record.start),
            );
          },
        );
      },
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.record,
    required this.forecast,
    required this.isNewest,
    required this.gapFromOlder,
  });

  final PeriodRecord record;
  final CycleForecast forecast;
  final bool isNewest;

  /// Days since the previous period started; null for the oldest record.
  final int? gapFromOlder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = CycleColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final ongoing = forecast.isOngoing && record.id == forecast.current!.id;
    final end = record.end;
    final gap = gapFromOlder;
    final status = ongoing
        ? '进行中，今天是第 ${forecast.periodDay} 天'
        : end == null
        ? '没有记录结束日期'
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: isNewest ? Colors.transparent : colors.track,
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.period,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: gap == null ? Colors.transparent : colors.track,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => showRecordEditor(context, record: record),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                end == null
                                    ? '${formatDay(record.start)} 开始'
                                    : formatSpan(record.start, end),
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            if (record.length case final length?)
                              DayCount(length, color: colors.period),
                          ],
                        ),
                        if (status != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              status,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ),
                        if (record.note case final note?)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              note,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (gap != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                    child: _GapLabel(gap),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GapLabel extends StatelessWidget {
  const _GapLabel(this.days);

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final warning = days > CycleRules.maxCycle
        ? '，中间可能漏记了一次'
        : days < CycleRules.minCycle
        ? '，间隔太短，请检查日期'
        : null;
    return DefaultTextStyle.merge(
      style: theme.textTheme.bodySmall?.copyWith(color: muted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text('相隔 '),
          DayCount(days, size: 18, color: muted),
          if (warning != null) Flexible(child: Text(warning)),
        ],
      ),
    );
  }
}
