import 'package:flutter/widgets.dart';

import 'reminders.dart';

/// Makes [Reminders] available below it and rebuilds dependents when they
/// change. Left out where the platform can't post reminders.
class ReminderScope extends InheritedNotifier<Reminders> {
  const ReminderScope({
    super.key,
    required Reminders reminders,
    required super.child,
  }) : super(notifier: reminders);

  /// The reminders, or null where there are none; [context] rebuilds
  /// whenever they change.
  static Reminders? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReminderScope>()?.notifier;
}
