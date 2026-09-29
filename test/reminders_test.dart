import 'package:flutter_test/flutter_test.dart';
import 'package:luna_care/src/app.dart';
import 'package:luna_care/src/data/cycle_repository.dart';
import 'package:luna_care/src/data/key_value_store.dart';
import 'package:luna_care/src/models/cycle_settings.dart';
import 'package:luna_care/src/models/period_record.dart';
import 'package:luna_care/src/models/reminder_settings.dart';
import 'package:luna_care/src/state/cycle_store.dart';
import 'package:luna_care/src/state/reminders.dart';
import 'package:luna_care/src/utils/dates.dart';

import 'fake_scheduler.dart';

final now = DateTime(2026, 9, 29, 12); // A Tuesday.
final today = dateOnly(now);

void main() {
  late KeyValueStore storage;
  late CycleStore store;
  late FakeScheduler scheduler;

  Reminders open() => Reminders(
    store: store,
    repository: CycleRepository(storage),
    scheduler: scheduler,
    clock: () => now,
  );

  setUp(() async {
    storage = MemoryKeyValueStore();
    store = CycleStore(CycleRepository(storage), clock: () => now);
    scheduler = FakeScheduler();
    // Started 20 days ago: with a 28-day cycle, next expected on 7 October.
    await store.saveRecord(
      PeriodRecord(
        id: 'a',
        start: addDays(today, -20),
        end: addDays(today, -16),
      ),
    );
  });

  group('Reminders', () {
    test('stay off when notifications are refused', () async {
      scheduler.grantsPermission = false;
      final reminders = open();

      expect(await reminders.enable(), isFalse);
      await reminders.synced;
      expect(reminders.settings.enabled, isFalse);
      expect(reminders.allowed, isFalse);
      expect(scheduler.scheduled, isEmpty);
    });

    test('schedule the next period once on, and remember it', () async {
      final reminders = open();
      expect(await reminders.enable(), isTrue);
      await reminders.synced;
      expect(scheduler.scheduled.map((r) => r.time), [
        DateTime(2026, 10, 5, 9),
        DateTime(2026, 10, 7, 9),
      ]);

      final reopened = open();
      expect(reopened.settings.enabled, isTrue);
    });

    test('follow the records, the name and the settings', () async {
      final reminders = open();
      await reminders.enable();

      // She came early, today: the next reminders move a cycle on.
      await store.saveRecord(PeriodRecord(id: 'b', start: today));
      await reminders.synced;
      expect(scheduler.scheduled.map((r) => r.periodStart).toSet(), {
        addDays(today, 20),
      });

      await store.updateSettings(const CycleSettings(partnerName: '小月'));
      await reminders.synced;
      expect(scheduler.scheduled.first.title, startsWith('小月'));

      await reminders.update(
        reminders.settings.copyWith(daysBefore: 3, minuteOfDay: 20 * 60),
      );
      await reminders.synced;
      expect(scheduler.scheduled.first.time, DateTime(2026, 10, 16, 20));

      await store.clearRecords();
      await reminders.synced;
      expect(scheduler.scheduled, isEmpty);
    });

    test('cancel everything when turned off', () async {
      final reminders = open();
      await reminders.enable();
      await reminders.update(reminders.settings.copyWith(enabled: false));
      await reminders.synced;
      expect(scheduler.scheduled, isEmpty);
    });

    test('leave the phone alone when nothing changed', () async {
      final reminders = open();
      await reminders.enable();
      await reminders.synced;
      final before = scheduler.replacements;

      await store.updateSettings(store.settings);
      await reminders.update(reminders.settings);
      await reminders.synced;
      expect(scheduler.replacements, before);
    });

    test('recover from a failed update at the next change', () async {
      final reminders = open();
      scheduler.failing = true;
      await reminders.enable();
      await reminders.synced;
      expect(scheduler.scheduled, isEmpty);

      scheduler.failing = false;
      await store.updateSettings(const CycleSettings(partnerName: '小月'));
      await reminders.synced;
      expect(scheduler.scheduled, hasLength(2));
    });

    test('a test notification says when the next reminder comes', () async {
      final reminders = open();
      expect(await reminders.sendTest(), isFalse);
      expect(scheduler.shown, isEmpty);

      await reminders.enable();
      expect(await reminders.sendTest(), isTrue);
      expect(scheduler.shown.single, contains('10月5日 周一 09:00'));
    });
  });

  group('Settings', () {
    Future<Reminders> openSettings(WidgetTester tester) async {
      final reminders = open();
      await tester.pumpWidget(LunaCareApp(store: store, reminders: reminders));
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      return reminders;
    }

    testWidgets('turn reminders on and adjust them', (tester) async {
      await openSettings(tester);
      expect(find.text('预计经期开始前和当天各提醒一次'), findsOneWidget);
      expect(find.text('提前几天'), findsNothing);

      await tester.tap(find.text('经期提醒'));
      await tester.pumpAndSettle();
      expect(find.text('下次提醒：10月5日 周一 09:00'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      // The reminder stepper comes first, above the default lengths.
      await tester.tap(find.byTooltip('多一天').first);
      await tester.pumpAndSettle();
      expect(find.text('下次提醒：10月4日 周日 09:00'), findsOneWidget);

      await tester.tap(find.text('发一条测试提醒'));
      await tester.pumpAndSettle();
      expect(find.text('已发送，看看通知栏'), findsOneWidget);
      expect(scheduler.shown, hasLength(1));

      await tester.tap(find.text('经期提醒'));
      await tester.pumpAndSettle();
      expect(find.text('提前几天'), findsNothing);
      expect(scheduler.scheduled, isEmpty);
    });

    testWidgets('a refusal leaves reminders off and points to settings', (
      tester,
    ) async {
      scheduler.grantsPermission = false;
      await openSettings(tester);

      await tester.tap(find.text('经期提醒'));
      await tester.pumpAndSettle();
      expect(find.text('没有通知权限，提醒发不出来。'), findsOneWidget);
      expect(find.text('提前几天'), findsNothing);

      await tester.tap(find.text('去设置'));
      expect(scheduler.settingsOpened, 1);
    });

    testWidgets('notifications turned off in the system are flagged', (
      tester,
    ) async {
      await CycleRepository(
        storage,
      ).saveReminderSettings(const ReminderSettings(enabled: true));
      await openSettings(tester);

      expect(find.text('通知被关掉了'), findsOneWidget);
      await tester.tap(find.text('通知被关掉了'));
      expect(scheduler.settingsOpened, 1);
    });
  });
}
