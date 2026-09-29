import 'package:flutter_test/flutter_test.dart';
import 'package:luna_care/src/data/cycle_repository.dart';
import 'package:luna_care/src/data/key_value_store.dart';
import 'package:luna_care/src/models/cycle_settings.dart';
import 'package:luna_care/src/models/period_record.dart';
import 'package:luna_care/src/state/cycle_store.dart';
import 'package:luna_care/src/utils/dates.dart';

void main() {
  final today = todayDate();
  PeriodRecord record(String id, int startDaysAgo, [int? endDaysAgo]) =>
      PeriodRecord(
        id: id,
        start: addDays(today, -startDaysAgo),
        end: endDaysAgo == null ? null : addDays(today, -endDaysAgo),
      );

  late CycleStore store;
  setUp(() => store = CycleStore(CycleRepository(MemoryKeyValueStore())));

  test('saves records and settings to storage', () async {
    final storage = MemoryKeyValueStore();
    final first = CycleStore(CycleRepository(storage));
    await first.saveRecord(
      PeriodRecord(
        id: 'a',
        start: addDays(today, -30),
        end: addDays(today, -26),
        note: '量多',
      ),
    );
    await first.updateSettings(
      const CycleSettings(partnerName: '小月', cycleLength: 30),
    );

    final reopened = CycleStore(CycleRepository(storage));
    expect(reopened.forecast.records.single.note, '量多');
    expect(reopened.settings.partnerName, '小月');
    expect(reopened.settings.cycleLength, 30);
  });

  test('rejects impossible or overlapping records', () async {
    await store.saveRecord(record('a', 30, 26));
    expect(store.validate(record('b', 28, 25)), contains('重叠'));
    expect(store.validate(record('b', 10, 12)), isNotNull);
    expect(store.validate(record('b', -1)), isNotNull);
    expect(store.validate(record('b', 3, -1)), isNotNull);
    expect(store.validate(record('b', 60, 40)), isNotNull);
    expect(store.validate(record('b', 3)), isNull);
    // A record never collides with its own earlier version.
    expect(store.validate(record('a', 29, 25)), isNull);
  });

  test('an ongoing period blocks a second start inside it', () async {
    await store.saveRecord(record('a', 8));
    expect(store.forecast.isOngoing, isTrue);
    expect(store.validate(record('b', 0)), contains('重叠'));
  });

  test('the day moves on only through refreshDate, which notifies', () {
    var now = DateTime(2026, 9, 29, 23, 59);
    final clocked = CycleStore(
      CycleRepository(MemoryKeyValueStore()),
      clock: () => now,
    );
    var notified = 0;
    clocked.addListener(() => notified++);
    expect(clocked.forecast.today, DateTime(2026, 9, 29));

    now = DateTime(2026, 9, 30, 0, 1);
    // Reading the forecast after midnight must not switch days silently,
    // or screens that were already built would stay on yesterday.
    expect(clocked.forecast.today, DateTime(2026, 9, 29));
    clocked.refreshDate();
    expect(notified, 1);
    expect(clocked.forecast.today, DateTime(2026, 9, 30));
    clocked.refreshDate();
    expect(notified, 1);
  });

  test('undo reverts a record only if it has not changed since', () async {
    final open = record('a', 3);
    await store.saveRecord(open);
    final ended = open.withEnd(today);
    await store.saveRecord(ended);

    // Undoing the start now would also throw away the recorded end.
    expect(await store.revert(id: 'a', after: open), isFalse);
    expect(store.forecast.records.single, ended);

    expect(await store.revert(id: 'a', before: open, after: ended), isTrue);
    expect(store.forecast.records.single, open);
  });

  test('undoing a delete will not overlap a newer record', () async {
    final old = record('a', 30, 26);
    await store.saveRecord(old);
    await store.deleteRecord('a');
    await store.saveRecord(record('b', 28, 25));
    expect(await store.revert(id: 'a', before: old), isFalse);
    expect(store.forecast.records.single.id, 'b');
  });

  test('backups holding records the app would reject are refused', () {
    String? check(List<PeriodRecord> records) => CycleStore.checkBackup(
      Backup(records: records, settings: const CycleSettings()),
    );
    expect(check([record('a', 30, 26), record('b', 2)]), isNull);
    expect(check([record('a', 26, 30)]), contains('结束日期'));
    expect(check([record('a', 30, 26), record('a', 2)]), contains('重复'));
    expect(check([record('a', -3)]), contains('开始日期'));
    expect(check([record('a', 30, 26), record('b', 28, 25)]), contains('重叠'));
  });

  test('unreadable saved data is skipped instead of crashing', () {
    final storage = MemoryKeyValueStore({
      CycleRepository.recordsKey:
          '[{"id":"a","start":"2026-09-01","end":"2026-09-05"},{"id":2},"x"]',
      CycleRepository.settingsKey: '{not json',
    });
    final reopened = CycleStore(CycleRepository(storage));
    expect(reopened.forecast.records.single.id, 'a');
    expect(reopened.settings.cycleLength, CycleSettings.defaultCycleLength);

    final garbage = MemoryKeyValueStore({CycleRepository.recordsKey: 'oops'});
    expect(CycleStore(CycleRepository(garbage)).forecast.records, isEmpty);
  });

  test('backups round-trip and reject other text', () async {
    await store.saveRecord(record('a', 30, 26));
    await store.updateSettings(const CycleSettings(partnerName: '小月'));

    final backup = Backup.decode(store.exportBackup());
    expect(backup.records.single, record('a', 30, 26));
    expect(backup.settings.partnerName, '小月');

    final fresh = CycleStore(CycleRepository(MemoryKeyValueStore()));
    await fresh.restore(backup);
    expect(fresh.forecast.records, hasLength(1));
    expect(fresh.settings.partnerName, '小月');

    expect(() => Backup.decode('hello'), throwsFormatException);
    expect(
      () => Backup.decode('{"app":"Other","records":[]}'),
      throwsFormatException,
    );
    expect(
      () => Backup.decode('{"app":"LunaCare","records":[{"id":1}]}'),
      throwsFormatException,
    );
  });
}
