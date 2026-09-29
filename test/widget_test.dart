import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_care/src/app.dart';
import 'package:luna_care/src/data/cycle_repository.dart';
import 'package:luna_care/src/data/key_value_store.dart';
import 'package:luna_care/src/models/period_record.dart';
import 'package:luna_care/src/state/cycle_store.dart';
import 'package:luna_care/src/utils/dates.dart';

void main() {
  testWidgets('records a period starting and ending from the today tab', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final store = CycleStore(CycleRepository(MemoryKeyValueStore()));
    await tester.pumpWidget(LunaCareApp(store: store));
    expect(find.text('还没有记录'), findsOneWidget);

    final today = todayDate();
    await store.saveRecord(
      PeriodRecord(
        id: 'a',
        start: addDays(today, -40),
        end: addDays(today, -36),
      ),
    );
    await store.saveRecord(
      PeriodRecord(
        id: 'b',
        start: addDays(today, -12),
        end: addDays(today, -8),
      ),
    );
    await tester.pump();

    // Two starts 28 days apart put the next period 16 days away.
    expect(find.text('还有'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);

    await tester.tap(find.text('她今天来月经了'));
    await tester.pump();
    expect(find.text('经期第'), findsOneWidget);
    expect(store.forecast.isOngoing, isTrue);

    await tester.tap(find.text('月经今天结束了'));
    await tester.pump();
    expect(store.forecast.current!.end, today);
    expect(find.text('今天是这次月经的最后一天'), findsOneWidget);
  });

  testWidgets('every tab renders', (tester) async {
    final today = todayDate();
    final store = CycleStore(CycleRepository(MemoryKeyValueStore()));
    await store.saveRecord(
      PeriodRecord(
        id: 'a',
        start: addDays(today, -35),
        end: addDays(today, -31),
      ),
    );
    await store.saveRecord(
      PeriodRecord(id: 'b', start: addDays(today, -6), end: addDays(today, -2)),
    );

    for (final tab in [0, 1, 2]) {
      await tester.pumpWidget(
        LunaCareApp(key: ValueKey(tab), store: store, initialTab: tab),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('相隔 '), findsOneWidget);
  });
}
