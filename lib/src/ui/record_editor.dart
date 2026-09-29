import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/cycle_forecast.dart';
import '../models/period_record.dart';
import '../state/cycle_scope.dart';
import '../utils/dates.dart';
import 'notice.dart';

/// Opens the editor for [record], or for a new record starting on
/// [initialStart].
Future<void> showRecordEditor(
  BuildContext context, {
  PeriodRecord? record,
  DateTime? initialStart,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => RecordEditor(record: record, initialStart: initialStart),
);

/// Records that a period started on [day], offering an undo.
Future<void> startPeriodOn(BuildContext context, DateTime day) async {
  final store = CycleScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final record = PeriodRecord(id: PeriodRecord.newId(), start: day);
  if (store.validate(record) case final error?) {
    showNotice(messenger, error);
    return;
  }
  await store.saveRecord(record);
  HapticFeedback.lightImpact();
  showUndoableNotice(
    messenger,
    store,
    isSameDay(day, todayDate())
        ? '已记下：今天是经期第 1 天'
        : '已记下：${formatMonthDay(day)} 来了月经',
    id: record.id,
    after: record,
  );
}

/// Records that the period in [record] ended on [day], offering an undo.
Future<void> endPeriodOn(
  BuildContext context,
  PeriodRecord record,
  DateTime day,
) async {
  final store = CycleScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final ended = record.withEnd(day);
  if (store.validate(ended) case final error?) {
    showNotice(messenger, error);
    return;
  }
  await store.saveRecord(ended);
  HapticFeedback.lightImpact();
  showUndoableNotice(
    messenger,
    store,
    '已记下：这次月经持续了 ${ended.length} 天',
    id: record.id,
    before: record,
    after: ended,
  );
}

class RecordEditor extends StatefulWidget {
  const RecordEditor({super.key, this.record, this.initialStart});

  final PeriodRecord? record;
  final DateTime? initialStart;

  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  late DateTime _start;
  DateTime? _end;

  /// Once the end has been set by hand it no longer follows the start.
  bool _endChosen = false;

  late final TextEditingController _note;
  String? _error;

  bool get _isNew => widget.record == null;

  int get _periodLength => CycleScope.read(context).forecast.periodLength;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _note = TextEditingController(text: record?.note ?? '');
    if (record != null) {
      _start = record.start;
      _end = record.end;
      _endChosen = true;
    } else {
      _start = dateOnly(widget.initialStart ?? todayDate());
      _end = _suggestedEnd();
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// A period that started long enough ago probably lasted the usual number
  /// of days; a recent one is probably still going on.
  DateTime? _suggestedEnd() {
    final end = addDays(_start, _periodLength - 1);
    return end.isBefore(todayDate()) ? end : null;
  }

  /// The end to offer when one is needed: the usual length, up to today.
  DateTime _defaultEnd() {
    final today = todayDate();
    final end = addDays(_start, _periodLength - 1);
    return end.isAfter(today) ? today : end;
  }

  DateTime get _latestEnd {
    final today = todayDate();
    final latest = addDays(_start, CycleRules.maxPeriod - 1);
    return latest.isAfter(today) ? today : latest;
  }

  Future<void> _pickStart() async {
    final today = todayDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start.isAfter(today) ? today : _start,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: '哪天开始的？',
    );
    if (picked == null) return;
    setState(() {
      _start = dateOnly(picked);
      final end = _end;
      if (!_endChosen) {
        _end = _suggestedEnd();
      } else if (end != null &&
          (end.isBefore(_start) || end.isAfter(_latestEnd))) {
        _end = _defaultEnd();
      }
      _error = null;
    });
  }

  Future<void> _pickEnd() async {
    final last = _latestEnd;
    if (last.isBefore(_start)) return; // A start in the future has no end yet.
    final current = _end ?? _defaultEnd();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(last) ? last : current,
      firstDate: _start,
      lastDate: last,
      helpText: '哪天结束的？',
    );
    if (picked == null) return;
    setState(() {
      _end = dateOnly(picked);
      _endChosen = true;
      _error = null;
    });
  }

  // Saving and deleting close the sheet straight away: the store updates at
  // once and writes in the background, so a second tap can't land on the
  // sheet, or close the page beneath it.

  void _save() {
    final store = CycleScope.read(context);
    final record = PeriodRecord(
      id: widget.record?.id ?? PeriodRecord.newId(),
      start: _start,
      end: _end,
      note: _note.text,
    );
    if (store.validate(record) case final error?) {
      setState(() => _error = error);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    unawaited(store.saveRecord(record));
    Navigator.of(context).pop();
    showNotice(messenger, '已保存');
  }

  void _delete() {
    final store = CycleScope.read(context);
    final record = widget.record!;
    final messenger = ScaffoldMessenger.of(context);
    unawaited(store.deleteRecord(record.id));
    Navigator.of(context).pop();
    showUndoableNotice(
      messenger,
      store,
      '已删除 ${formatDay(record.start)} 开始的记录',
      id: record.id,
      before: record,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // An open-ended period is "still going on" only if it started recently.
    final recent = daysBetween(_start, todayDate()) < CycleRules.maxPeriod;
    final end = _end;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isNew ? '补记一次月经' : '编辑记录', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _DateRow(
              label: '开始',
              value: '${formatFullDate(_start)} ${formatWeekday(_start)}',
              onTap: _pickStart,
            ),
            const Divider(),
            _DateRow(
              label: '结束',
              value: end == null
                  ? (recent ? '还没结束' : '不记得了')
                  : '${formatFullDate(end)} ${formatWeekday(end)}',
              muted: end == null,
              onTap: _pickEnd,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(recent ? '还没结束' : '不记得哪天结束的'),
              value: end == null,
              onChanged: (open) => setState(() {
                _end = open ? null : _defaultEnd();
                _endChosen = true;
                _error = null;
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: '备注（可不填）',
                hintText: '比如：痛经明显、量比较多',
              ),
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_isNew)
                  TextButton(
                    onPressed: _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('删除'),
                  ),
                Expanded(
                  // Stacks the buttons when large text leaves no room.
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.end,
                    spacing: 8,
                    overflowSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(foregroundColor: muted),
                        child: const Text('取消'),
                      ),
                      FilledButton(onPressed: _save, child: const Text('保存')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variant = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(color: variant),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: muted ? variant : theme.colorScheme.onSurface,
                  fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: variant),
          ],
        ),
      ),
    );
  }
}
