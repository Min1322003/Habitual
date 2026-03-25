import 'package:flutter/material.dart';

import 'data/habitual_repository.dart';
import 'ui/analytics/analytics_screen.dart';
import 'ui/calendar/calendar_screen.dart';
import 'ui/journaling/journaling_screen.dart';

class HabitualApp extends StatefulWidget {
  const HabitualApp({
    super.key,
    required this.repository,
  });

  final HabitualRepository repository;

  @override
  State<HabitualApp> createState() => _HabitualAppState();
}

class _HabitualAppState extends State<HabitualApp> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      CalendarScreen(repository: widget.repository),
      JournalingScreen(repository: widget.repository),
      AnalyticsScreen(repository: widget.repository),
    ];

    return MaterialApp(
      title: 'Habitual',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: screens[_tabIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
            NavigationDestination(icon: Icon(Icons.edit_document), label: 'Journal'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Insights'),
          ],
        ),
      ),
    );
  }
}

