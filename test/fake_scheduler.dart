import 'package:luna_care/src/data/reminder_scheduler.dart';
import 'package:luna_care/src/logic/reminder_plan.dart';

/// Stands in for the phone: records what gets scheduled and shown.
class FakeScheduler implements ReminderScheduler {
  bool allowed = false;
  bool grantsPermission = true;
  bool failing = false;
  List<PlannedReminder> scheduled = [];
  int replacements = 0;
  int settingsOpened = 0;
  final shown = <String>[];

  @override
  Future<bool> isAllowed() async => allowed;

  @override
  Future<bool> requestPermission() async {
    if (grantsPermission) allowed = true;
    return allowed;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    if (failing) throw Exception('alarm service unavailable');
    replacements++;
    scheduled = reminders;
  }

  @override
  Future<void> showNow({required String title, required String body}) async =>
      shown.add('$title $body');
}
