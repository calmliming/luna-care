import 'dart:async';

import 'package:flutter/material.dart';

import '../state/cycle_scope.dart';
import '../utils/dates.dart';
import 'calendar_tab.dart';
import 'record_editor.dart';
import 'records_tab.dart';
import 'settings_page.dart';
import 'today_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _tab = widget.initialTab;
  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    // A new day moves every countdown along, whether the app was in the
    // background or left open past midnight.
    _lifecycle = AppLifecycleListener(onResume: _refreshDate);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshDate() => CycleScope.read(context).refreshDate();

  void _scheduleMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(
      tomorrow.difference(now) + const Duration(seconds: 1),
      () {
        _refreshDate();
        _scheduleMidnight();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = CycleScope.of(context).forecast.today;
    final titles = [formatMonthDayWeekday(today), '日历', '记录'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [TodayTab(), CalendarTab(), RecordsTab()],
      ),
      floatingActionButton: _tab == 2
          ? FloatingActionButton.extended(
              onPressed: () => showRecordEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('补记'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.nightlight_outlined),
            selectedIcon: Icon(Icons.nightlight),
            label: '今天',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '记录',
          ),
        ],
      ),
    );
  }
}
