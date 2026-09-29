import 'package:flutter/foundation.dart';

import '../data/cycle_repository.dart';
import '../data/reminder_scheduler.dart';
import '../logic/reminder_plan.dart';
import '../models/reminder_settings.dart';
import '../utils/dates.dart';
import 'cycle_store.dart';

/// Holds the reminder settings and keeps the notifications scheduled on the
/// phone in step with them and with the records in the [CycleStore].
class Reminders extends ChangeNotifier {
  Reminders({
    required this._store,
    required CycleRepository repository,
    required this._scheduler,
    this._clock = DateTime.now,
  }) : _repository = repository,
       _settings = repository.loadReminderSettings() {
    _store.addListener(_sync);
    _sync();
  }

  final CycleStore _store;
  final CycleRepository _repository;
  final ReminderScheduler _scheduler;
  final DateTime Function() _clock;
  ReminderSettings _settings;
  bool? _allowed;

  /// Plans reach the scheduler one after another, so an older plan can never
  /// land after a newer one.
  Future<void> _syncing = Future.value();
  List<PlannedReminder>? _scheduled;

  ReminderSettings get settings => _settings;

  /// Whether the phone lets the app post notifications, as of the last
  /// [checkPermission] or [enable]; null before either.
  bool? get allowed => _allowed;

  /// The reminders that should be scheduled now, soonest first.
  List<PlannedReminder> get planned => planReminders(
    forecast: _store.forecast,
    settings: _settings,
    name: _store.settings.displayName,
    now: _clock(),
  );

  /// Completes once every change so far has reached the scheduler.
  @visibleForTesting
  Future<void> get synced => _syncing;

  /// Looks again at whether notifications are allowed, which can change in
  /// system settings while the app is in the background.
  Future<void> checkPermission() async {
    final allowed = await _scheduler.isAllowed();
    if (allowed == _allowed) return;
    _allowed = allowed;
    notifyListeners();
  }

  /// Turns reminders on, asking for permission to notify first. Returns
  /// false, leaving them off, when the phone doesn't allow notifications.
  Future<bool> enable() async {
    final allowed = await _scheduler.requestPermission();
    _allowed = allowed;
    if (!allowed) {
      notifyListeners();
      return false;
    }
    await update(_settings.copyWith(enabled: true));
    return true;
  }

  Future<void> update(ReminderSettings settings) async {
    _settings = settings;
    notifyListeners();
    _sync();
    await _repository.saveReminderSettings(settings);
  }

  Future<void> openSystemSettings() => _scheduler.openSettings();

  /// Posts a notification now, to check they get through. Returns false
  /// when the phone doesn't allow notifications.
  Future<bool> sendTest() async {
    await checkPermission();
    if (_allowed != true) return false;
    final next = planned.firstOrNull;
    await _scheduler.showNow(
      title: '提醒测试',
      body: [
        '看到这条，说明通知能正常显示。',
        if (next != null) '下一次经期提醒在 ${formatMonthDayWeekdayClock(next.time)}。',
      ].join(),
    );
    return true;
  }

  void _sync() => _syncing = _syncing.then((_) => _apply());

  Future<void> _apply() async {
    final plan = planned;
    if (listEquals(plan, _scheduled)) return;
    try {
      await _scheduler.replaceAll(plan);
      _scheduled = plan;
    } catch (error) {
      // Leave it for the next change to retry; a failure must not end the
      // chain in _syncing, or no later plan would ever be applied.
      debugPrint('Could not schedule reminders: $error');
    }
  }

  @override
  void dispose() {
    _store.removeListener(_sync);
    super.dispose();
  }
}
