import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/cycle_scope.dart';
import 'state/cycle_store.dart';
import 'state/reminder_scope.dart';
import 'state/reminders.dart';
import 'theme.dart';
import 'ui/home_shell.dart';

class LunaCareApp extends StatelessWidget {
  const LunaCareApp({
    super.key,
    required this.store,
    this.reminders,
    this.initialTab = 0,
  });

  final CycleStore store;

  /// Null where the platform can't post reminders, which hides their
  /// settings.
  final Reminders? reminders;

  final int initialTab;

  static const _locale = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
    countryCode: 'CN',
  );

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'LunaCare',
      debugShowCheckedModeBanner: false,
      theme: LunaTheme.light(),
      darkTheme: LunaTheme.dark(),
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomeShell(initialTab: initialTab),
    );
    return CycleScope(
      store: store,
      child: switch (reminders) {
        final reminders? => ReminderScope(reminders: reminders, child: app),
        null => app,
      },
    );
  }
}
