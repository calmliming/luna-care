import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/data/cycle_repository.dart';
import 'src/data/reminder_scheduler.dart';
import 'src/state/cycle_store.dart';
import 'src/state/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await CycleRepository.open();
  final store = CycleStore(repository);
  final reminders = await _openReminders(store, repository);
  runApp(LunaCareApp(store: store, reminders: reminders));
}

/// Reminders on Android. Elsewhere, such as the browser preview, the app
/// runs without them.
Future<Reminders?> _openReminders(
  CycleStore store,
  CycleRepository repository,
) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    return Reminders(
      store: store,
      repository: repository,
      scheduler: await AndroidReminderScheduler.open(),
    );
  } catch (error) {
    // Reminders are an extra; they must never keep the app from opening.
    debugPrint('Reminders unavailable: $error');
    return null;
  }
}
