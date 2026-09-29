import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cycle_repository.dart';
import '../models/cycle_settings.dart';
import '../models/reminder_settings.dart';
import '../state/cycle_scope.dart';
import '../state/cycle_store.dart';
import '../state/reminder_scope.dart';
import '../state/reminders.dart';
import '../utils/dates.dart';
import 'notice.dart';
import 'widgets/day_count.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CycleScope.of(context);
    final settings = store.settings;
    final hasRecords = store.forecast.records.isNotEmpty;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.6,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            title: const Text('怎么称呼她'),
            subtitle: Text(
              settings.partnerName.isEmpty
                  ? '未设置，显示为“她”'
                  : settings.partnerName,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editName(context),
          ),
          if (ReminderScope.maybeOf(context) case final reminders?) ...[
            const Divider(indent: 24, endIndent: 24),
            const _SectionTitle('提醒'),
            _ReminderSettings(reminders: reminders),
          ],
          const Divider(indent: 24, endIndent: 24),
          const _SectionTitle('默认天数'),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              '记录还不够时按这里的天数推算：记下两次间隔正常的月经后，'
              '周期按实际计算；记下结束日期后，经期按实际计算。',
              style: muted,
            ),
          ),
          _StepperRow(
            label: '周期长度',
            value: settings.cycleLength,
            range: CycleSettings.cycleLengthRange,
            onChanged: (days) =>
                store.updateSettings(settings.copyWith(cycleLength: days)),
          ),
          _StepperRow(
            label: '经期长度',
            value: settings.periodLength,
            range: CycleSettings.periodLengthRange,
            onChanged: (days) =>
                store.updateSettings(settings.copyWith(periodLength: days)),
          ),
          const SizedBox(height: 8),
          const Divider(indent: 24, endIndent: 24),
          const _SectionTitle('备份'),
          ListTile(
            title: const Text('复制备份'),
            subtitle: const Text('把所有记录复制到剪贴板，可以粘贴到备忘录或发给自己保存'),
            onTap: () => _copyBackup(context),
          ),
          ListTile(
            title: const Text('从剪贴板恢复'),
            subtitle: const Text('用复制的备份替换现在的记录'),
            onTap: () => _restore(context),
          ),
          ListTile(
            enabled: hasRecords,
            title: Text(
              '清空所有记录',
              style: TextStyle(
                color: hasRecords ? theme.colorScheme.error : null,
              ),
            ),
            onTap: () => _clear(context),
          ),
          const Divider(indent: 24, endIndent: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              '记录只保存在这台手机上，卸载应用会一并删除，换手机前记得复制备份。\n'
              '预测根据过往记录推算，仅供参考，不能用于避孕。',
              style: muted,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _editName(BuildContext context) async {
    final store = CycleScope.read(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: store.settings.partnerName),
    );
    if (name == null) return;
    await store.updateSettings(
      store.settings.copyWith(partnerName: name.trim()),
    );
  }

  static Future<void> _copyBackup(BuildContext context) async {
    final store = CycleScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: store.exportBackup()));
    showNotice(messenger, '已复制 ${store.forecast.records.length} 条记录的备份');
  }

  static Future<void> _restore(BuildContext context) async {
    final store = CycleScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final Backup backup;
    try {
      backup = Backup.decode(data?.text ?? '');
    } on FormatException {
      showNotice(messenger, '剪贴板里没有 LunaCare 的备份。先在原来的手机上点“复制备份”。');
      return;
    }
    // A hand-edited backup could carry records the app would never accept.
    if (CycleStore.checkBackup(backup) case final problem?) {
      showNotice(messenger, '无法恢复：$problem');
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从剪贴板恢复？'),
        content: Text(
          '备份里有 ${backup.records.length} 条记录，'
          '会替换现在的 ${store.forecast.records.length} 条记录和设置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.restore(backup);
    showNotice(messenger, '已恢复 ${backup.records.length} 条记录');
  }

  static Future<void> _clear(BuildContext context) async {
    final store = CycleScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final count = store.forecast.records.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有记录？'),
        content: Text('$count 条记录都会被删除，无法撤销，设置会保留。需要的话先复制备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.clearRecords();
    showNotice(messenger, '已清空所有记录');
  }
}

/// The reminder switch and, once it is on, when reminders come.
class _ReminderSettings extends StatefulWidget {
  const _ReminderSettings({required this.reminders});

  final Reminders reminders;

  @override
  State<_ReminderSettings> createState() => _ReminderSettingsState();
}

class _ReminderSettingsState extends State<_ReminderSettings> {
  late final AppLifecycleListener _lifecycle;

  Reminders get _reminders => widget.reminders;

  @override
  void initState() {
    super.initState();
    // Notifications can be turned off, or back on, in system settings.
    _reminders.checkPermission();
    _lifecycle = AppLifecycleListener(onResume: _reminders.checkPermission);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _reminders.settings;
    final error = Theme.of(context).colorScheme.error;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('经期提醒'),
          subtitle: Text(_summary(CycleScope.of(context))),
          value: settings.enabled,
          onChanged: (on) => on
              ? _enable()
              : _reminders.update(settings.copyWith(enabled: false)),
        ),
        if (settings.enabled) ...[
          if (_reminders.allowed == false)
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: error),
              title: Text('通知被关掉了', style: TextStyle(color: error)),
              subtitle: const Text('系统不允许 LunaCare 发通知，提醒不会出现。点这里去打开。'),
              onTap: _reminders.openSystemSettings,
            ),
          _StepperRow(
            label: '提前几天',
            value: settings.daysBefore,
            range: ReminderSettings.daysBeforeRange,
            onChanged: (days) =>
                _reminders.update(settings.copyWith(daysBefore: days)),
          ),
          ListTile(
            title: const Text('提醒时间'),
            trailing: Text(
              formatClock(settings.hour, settings.minute),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: _pickTime,
          ),
          ListTile(
            title: const Text('发一条测试提醒'),
            subtitle: const Text('看看这台手机能不能收到'),
            onTap: _sendTest,
          ),
        ],
      ],
    );
  }

  String _summary(CycleStore store) {
    if (!_reminders.settings.enabled) return '预计经期开始前和当天各提醒一次';
    if (_reminders.planned.firstOrNull case final next?) {
      return '下次提醒：${formatMonthDayWeekdayClock(next.time)}';
    }
    final forecast = store.forecast;
    if (!forecast.hasData) return '记下一次月经后，就能安排提醒';
    if (forecast.isStale) return '很久没有新记录了，补上最近一次月经后继续提醒';
    // She is late, or today's reminder has already gone off.
    return '记下这次月经后，会安排下一次提醒';
  }

  Future<void> _enable() async {
    final messenger = ScaffoldMessenger.of(context);
    if (await _reminders.enable()) return;
    _showBlocked(messenger, '没有通知权限，提醒发不出来。');
  }

  Future<void> _pickTime() async {
    final settings = _reminders.settings;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
      helpText: '提醒时间',
    );
    if (time == null) return;
    await _reminders.update(
      _reminders.settings.copyWith(minuteOfDay: time.hour * 60 + time.minute),
    );
  }

  Future<void> _sendTest() async {
    final messenger = ScaffoldMessenger.of(context);
    if (await _reminders.sendTest()) {
      showNotice(messenger, '已发送，看看通知栏');
    } else {
      _showBlocked(messenger, '系统不允许 LunaCare 发通知。');
    }
  }

  void _showBlocked(ScaffoldMessengerState messenger, String message) {
    showNotice(
      messenger,
      message,
      action: SnackBarAction(
        label: '去设置',
        onPressed: _reminders.openSystemSettings,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.range,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ({int min, int max}) range;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          IconButton.outlined(
            tooltip: '少一天',
            onPressed: value > range.min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72),
            child: Center(child: DayCount(value)),
          ),
          IconButton.outlined(
            tooltip: '多一天',
            onPressed: value < range.max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('怎么称呼她'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 10,
        decoration: const InputDecoration(hintText: '比如：小月，不填就显示“她”'),
        onSubmitted: (name) => Navigator.of(context).pop(name),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
