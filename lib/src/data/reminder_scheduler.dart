import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../logic/reminder_plan.dart';
import '../theme.dart';

/// The phone's side of reminders, small enough that tests can swap in a fake.
abstract interface class ReminderScheduler {
  /// Whether the app may post notifications right now.
  Future<bool> isAllowed();

  /// Asks for permission to post notifications where the system wants one
  /// (Android 13 and later); true once notifications are allowed.
  Future<bool> requestPermission();

  /// Opens the system screen where notifications for the app are turned on.
  Future<void> openSettings();

  /// Makes [reminders] the only ones scheduled. Notifications already on
  /// screen stay where they are.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Posts a notification straight away.
  Future<void> showNow({required String title, required String body});
}

/// Android notifications through flutter_local_notifications.
class AndroidReminderScheduler implements ReminderScheduler {
  AndroidReminderScheduler._(this._plugin);

  /// Sets up the plugin; call once before the app starts.
  static Future<AndroidReminderScheduler> open() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        // The moon from the app icon, drawn white on transparent as Android
        // wants for the status bar: android/app/src/main/res/drawable.
        android: AndroidInitializationSettings('ic_stat_luna'),
      ),
    );
    return AndroidReminderScheduler._(
      plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!,
    );
  }

  final AndroidFlutterLocalNotificationsPlugin _plugin;

  /// Id for notifications shown on the spot; planned ones are far larger.
  static const _immediateId = 1;

  @override
  Future<bool> isAllowed() async =>
      await _plugin.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestPermission() async {
    try {
      return await _plugin.requestNotificationsPermission() ?? false;
    } on PlatformException {
      // A request is already showing, say after a double tap; this one
      // reports the current state rather than asking twice.
      return isAllowed();
    }
  }

  @override
  Future<void> openSettings() async {
    await _plugin.openAppNotificationSettings();
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _plugin.cancelAllPendingNotifications();
    // Inexact alarms may come up to an hour late. The manifest asks for exact
    // ones, but should the system still refuse, a late reminder beats none.
    final mode = await _plugin.canScheduleExactNotifications() ?? false
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final reminder in reminders) {
      // The plugin refuses times in the past, which a reminder due right
      // now may have become by the time it gets here.
      if (!reminder.time.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        // The instant, expressed in UTC, is all Android needs; it saves
        // looking up the phone's time zone by name.
        scheduledDate: tz.TZDateTime.from(reminder.time, tz.UTC),
        notificationDetails: _details(reminder.body),
        scheduleMode: mode,
      );
    }
  }

  @override
  Future<void> showNow({required String title, required String body}) =>
      _plugin.show(
        id: _immediateId,
        title: title,
        body: body,
        notificationDetails: _details(body),
      );

  static AndroidNotificationDetails _details(String body) =>
      AndroidNotificationDetails(
        'period',
        '经期提醒',
        channelDescription: '预计经期开始前和当天的提醒',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        color: LunaPalette.rouge,
        // Shows the whole message once expanded, not just its first line.
        styleInformation: BigTextStyleInformation(body),
      );
}
