import 'package:flutter/widgets.dart';

import 'cycle_store.dart';

/// Makes the [CycleStore] available below it and rebuilds dependents when it
/// changes.
class CycleScope extends InheritedNotifier<CycleStore> {
  const CycleScope({super.key, required CycleStore store, required super.child})
    : super(notifier: store);

  /// The store; [context] rebuilds whenever it changes.
  static CycleStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CycleScope>()!.notifier!;

  /// The store, for event handlers that shouldn't subscribe to changes.
  static CycleStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CycleScope>()!.notifier!;
}
