import 'package:flutter/material.dart';

import '../models/period_record.dart';
import '../state/cycle_store.dart';

/// Shows [message] in place of any snack bar still on screen, so messages
/// never queue up behind one another.
void showNotice(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        // A snack bar with an action stays up until dismissed by default;
        // these are routine confirmations, so let them time out.
        persist: false,
      ),
    );
}

/// Shows [message] with an undo that puts one record back the way it was
/// [before] the change, as long as it still looks the way it did [after].
void showUndoableNotice(
  ScaffoldMessengerState messenger,
  CycleStore store,
  String message, {
  required String id,
  PeriodRecord? before,
  PeriodRecord? after,
}) {
  showNotice(
    messenger,
    message,
    action: SnackBarAction(
      label: '撤销',
      onPressed: () async {
        final undone = await store.revert(id: id, before: before, after: after);
        if (!undone) showNotice(messenger, '撤销不了，记录在那之后又有改动');
      },
    ),
  );
}
