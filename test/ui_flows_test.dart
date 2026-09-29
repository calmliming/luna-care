import 'package:flutter/material.dart';
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

/// Three recorded periods 29 days apart, the latest ended two days ago.
Future<CycleStore> seededStore({String partnerName = ''}) async {
  final today = todayDate();
  final store = CycleStore(CycleRepository(MemoryKeyValueStore()));
  await store.saveRecord(
    PeriodRecord(
      id: 'a',
      start: addDays(today, -64),
      end: addDays(today, -60),
      note: '痛经明显，第二天量多',
    ),
  );
  await store.saveRecord(
    PeriodRecord(id: 'b', start: addDays(today, -35), end: addDays(today, -31)),
  );
  await store.saveRecord(
    PeriodRecord(id: 'c', start: addDays(today, -6), end: addDays(today, -2)),
  );
  await store.updateSettings(CycleSettings(partnerName: partnerName));
  return store;
}

void main() {
  testWidgets('large system text on a small phone never overflows', (
    tester,
  ) async {
    tester.view
      ..physicalSize =
          const Size(640, 1136) // 320 x 568, the smallest phones
      ..devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // The longest name the settings allow, for the longest button label.
    final store = await seededStore(partnerName: '一二三四五六七八九十');
    // Reminders on but blocked by the system shows every reminder row.
    final reminderRepository = CycleRepository(MemoryKeyValueStore());
    await reminderRepository.saveReminderSettings(
      const ReminderSettings(enabled: true),
    );
    final reminders = Reminders(
      store: store,
      repository: reminderRepository,
      scheduler: FakeScheduler(),
    );
    Future<void> open(int tab) async {
      await tester.pumpWidget(
        LunaCareApp(
          key: UniqueKey(),
          store: store,
          reminders: reminders,
          initialTab: tab,
        ),
      );
      await tester.pumpAndSettle();
    }

    await open(0);
    await open(1);
    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();
    expect(find.text('回到本月'), findsOneWidget);

    await open(2);
    // Bring the oldest record to the top, clear of the floating button.
    final oldest = find.textContaining('痛经明显');
    await tester.scrollUntilVisible(oldest, 200);
    await tester.ensureVisible(oldest);
    await tester.pumpAndSettle();
    await tester.tap(oldest);
    await tester.pumpAndSettle();
    expect(find.text('编辑记录'), findsOneWidget);
    // At this size the sheet scrolls; its buttons are below the fold.
    await tester.ensureVisible(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('通知被关掉了'), findsOneWidget);
    // Build every row, down to the note at the bottom.
    await tester.scrollUntilVisible(find.textContaining('不能用于避孕'), 200);
    expect(find.text('备份'), findsOneWidget);
  });

  testWidgets('the first period can be added from the empty state', (
    tester,
  ) async {
    final store = CycleStore(CycleRepository(MemoryKeyValueStore()));
    await tester.pumpWidget(LunaCareApp(store: store));

    await tester.tap(find.text('记录最近一次月经'));
    await tester.pumpAndSettle();
    expect(find.text('补记一次月经'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '量有点多');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('已保存'), findsOneWidget);
    expect(store.forecast.current?.note, '量有点多');
    expect(store.forecast.isOngoing, isTrue);
    expect(find.text('经期第'), findsOneWidget);
  });

  testWidgets('each message replaces the last and undo reverts the latest', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = await seededStore();
    await tester.pumpWidget(LunaCareApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('她今天来月经了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月经今天结束了'));
    await tester.pumpAndSettle();
    expect(find.text('已记下：今天是经期第 1 天'), findsNothing);
    expect(find.text('已记下：这次月经持续了 1 天'), findsOneWidget);

    // Undo takes back only the end, leaving the period open.
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(store.forecast.isOngoing, isTrue);
    expect(store.forecast.records, hasLength(4));

    // Messages with an undo still time out instead of staying up.
    await tester.tap(find.text('月经今天结束了'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('已记下：这次月经持续了 1 天'), findsNothing);
  });

  testWidgets('a deleted record comes back with undo', (tester) async {
    final store = await seededStore();
    await tester.pumpWidget(LunaCareApp(store: store, initialTab: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('痛经明显'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(store.forecast.records, hasLength(2));

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(store.forecast.records, hasLength(3));
    expect(store.forecast.records.first.note, '痛经明显，第二天量多');
  });

  testWidgets('tapping a calendar day offers to record a period there', (
    tester,
  ) async {
    final store = await seededStore();
    await tester.pumpWidget(LunaCareApp(store: store, initialTab: 1));
    await tester.pumpAndSettle();

    // The day's ink layer sits on top of its number and takes the tap.
    await tester.tap(find.text('${todayDate().day}'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('这天来月经了'));
    await tester.pumpAndSettle();
    expect(find.text('补记一次月经'), findsOneWidget);
  });
}
