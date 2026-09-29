import 'package:flutter/foundation.dart';

import '../data/cycle_repository.dart';
import '../data/key_value_store.dart';
import '../logic/cycle_forecast.dart';
import '../models/cycle_settings.dart';
import '../models/period_record.dart';
import '../utils/dates.dart';

/// Holds the records and settings, saves every change, and hands out the
/// forecast for the current day.
class CycleStore extends ChangeNotifier {
  CycleStore(this._repository, {DateTime Function() clock = DateTime.now})
    : _clock = clock,
      _records = _sorted(_repository.loadRecords()),
      _settings = _repository.loadSettings(),
      _day = dateOnly(clock());

  final CycleRepository _repository;
  final DateTime Function() _clock;
  List<PeriodRecord> _records;
  CycleSettings _settings;

  /// The day the forecast, and so everything on screen, is based on. It only
  /// moves in [refreshDate] or with a change, both of which notify listeners,
  /// so no screen can quietly switch to a new day while others lag behind.
  DateTime _day;
  CycleForecast? _forecast;

  CycleSettings get settings => _settings;

  CycleForecast get forecast => _forecast ??= CycleForecast.compute(
    records: _records,
    settings: _settings,
    today: _day,
  );

  DateTime get _today => dateOnly(_clock());

  /// Moves on to the new day, rebuilding listeners, if the date has changed.
  /// Called when the app returns to the foreground and at midnight.
  void refreshDate() {
    if (!isSameDay(_day, _today)) _changed();
  }

  /// Why [record] can't be saved, or null when it can.
  String? validate(PeriodRecord record) {
    final today = _today;
    if (record.start.isAfter(today)) return '开始日期不能晚于今天';
    final end = record.end;
    if (end != null) {
      if (end.isBefore(record.start)) return '结束日期不能早于开始日期';
      if (end.isAfter(today)) return '结束日期不能晚于今天';
      if (record.length! > CycleRules.maxPeriod) {
        return '持续了 ${record.length} 天，超过 ${CycleRules.maxPeriod} 天了，请检查日期';
      }
    }
    final forecast = this.forecast;
    final lastDay = end ?? addDays(record.start, forecast.periodLength - 1);
    for (final other in _records) {
      if (other.id == record.id) continue;
      final overlaps =
          !record.start.isAfter(forecast.lastDayOf(other)) &&
          !other.start.isAfter(lastDay);
      if (overlaps) return '和 ${formatDay(other.start)} 开始的那次记录重叠了';
    }
    return null;
  }

  /// Adds [record], or replaces the record with the same id.
  Future<void> saveRecord(PeriodRecord record) => _setRecords([
    for (final existing in _records)
      if (existing.id != record.id) existing,
    record,
  ]);

  Future<void> deleteRecord(String id) => _setRecords([
    for (final record in _records)
      if (record.id != id) record,
  ]);

  /// Undoes a change to one record by putting [before] back, or removing the
  /// record when [before] is null. Changes nothing and returns false if the
  /// record no longer matches [after] (it was changed again since), or if
  /// [before] would now clash with other records.
  Future<bool> revert({
    required String id,
    PeriodRecord? before,
    PeriodRecord? after,
  }) async {
    if (_recordWithId(id) != after) return false;
    if (before == null) {
      await deleteRecord(id);
      return true;
    }
    if (validate(before) != null) return false;
    await saveRecord(before);
    return true;
  }

  Future<void> clearRecords() => _setRecords([]);

  Future<void> updateSettings(CycleSettings settings) async {
    _settings = settings;
    _changed();
    await _repository.saveSettings(settings);
  }

  String exportBackup() =>
      Backup(records: _records, settings: _settings).encode();

  /// Why [backup] can't be restored, or null when every record in it passes
  /// the same checks as one entered by hand.
  static String? checkBackup(Backup backup) {
    final scratch = CycleStore(CycleRepository(MemoryKeyValueStore()))
      .._settings = backup.settings;
    final ids = <String>{};
    for (final record in _sorted(backup.records)) {
      if (!ids.add(record.id)) return '备份里有重复的记录';
      if (scratch.validate(record) case final problem?) {
        return '${formatDay(record.start)} 开始的那条记录有问题：$problem';
      }
      scratch
        .._records = [...scratch._records, record]
        .._forecast = null;
    }
    return null;
  }

  /// Replaces all records and settings with the ones in [backup], which
  /// should have passed [checkBackup].
  Future<void> restore(Backup backup) async {
    _records = _sorted(backup.records);
    _settings = backup.settings;
    _changed();
    await _repository.saveRecords(_records);
    await _repository.saveSettings(_settings);
  }

  Future<void> _setRecords(List<PeriodRecord> records) async {
    _records = _sorted(records);
    _changed();
    await _repository.saveRecords(_records);
  }

  void _changed() {
    _day = _today;
    _forecast = null;
    notifyListeners();
  }

  PeriodRecord? _recordWithId(String id) {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  static List<PeriodRecord> _sorted(List<PeriodRecord> records) =>
      [...records]..sort((a, b) => a.start.compareTo(b.start));
}
