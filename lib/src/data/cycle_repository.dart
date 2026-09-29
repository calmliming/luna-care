import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/cycle_settings.dart';
import '../models/period_record.dart';
import '../models/reminder_settings.dart';
import '../utils/dates.dart';
import 'key_value_store.dart';

/// Loads and saves records and settings.
class CycleRepository {
  CycleRepository(this._store);

  static const recordsKey = 'records.v1';
  static const settingsKey = 'settings.v1';
  static const remindersKey = 'reminders.v1';

  /// The repository backed by device storage.
  static Future<CycleRepository> open() async => CycleRepository(
    await SharedPreferencesStore.open({recordsKey, settingsKey, remindersKey}),
  );

  final KeyValueStore _store;

  /// The saved records. Anything unreadable is skipped rather than allowed to
  /// stop the app from opening.
  List<PeriodRecord> loadRecords() {
    final json = _decode(recordsKey);
    return [
      if (json is List)
        for (final item in json) ?_readRecord(item),
    ];
  }

  CycleSettings loadSettings() => CycleSettings.fromJson(_decode(settingsKey));

  ReminderSettings loadReminderSettings() =>
      ReminderSettings.fromJson(_decode(remindersKey));

  Object? _decode(String key) {
    final raw = _store.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException catch (error) {
      debugPrint('Ignoring unreadable $key: $error');
      return null;
    }
  }

  static PeriodRecord? _readRecord(Object? json) {
    try {
      return PeriodRecord.fromJson(json);
    } on FormatException catch (error) {
      debugPrint('Skipping unreadable record: $error');
      return null;
    }
  }

  Future<void> saveRecords(List<PeriodRecord> records) => _store.setString(
    recordsKey,
    jsonEncode([for (final record in records) record.toJson()]),
  );

  Future<void> saveSettings(CycleSettings settings) =>
      _store.setString(settingsKey, jsonEncode(settings.toJson()));

  Future<void> saveReminderSettings(ReminderSettings settings) =>
      _store.setString(remindersKey, jsonEncode(settings.toJson()));
}

const _backupApp = 'LunaCare';

/// Everything the user entered, as text that can be pasted on a new phone.
class Backup {
  const Backup({required this.records, required this.settings});

  /// Reads text made by [encode]; throws [FormatException] for anything else.
  factory Backup.decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text.trim());
    } on FormatException {
      throw const FormatException('Not a LunaCare backup');
    }
    if (json case {'app': _backupApp, 'records': final List records}) {
      return Backup(
        records: [for (final record in records) PeriodRecord.fromJson(record)],
        settings: CycleSettings.fromJson((json as Map)['settings']),
      );
    }
    throw const FormatException('Not a LunaCare backup');
  }

  final List<PeriodRecord> records;
  final CycleSettings settings;

  String encode() => jsonEncode({
    'app': _backupApp,
    'format': 1,
    'exportedAt': toIsoDate(todayDate()),
    'settings': settings.toJson(),
    'records': [for (final record in records) record.toJson()],
  });
}
