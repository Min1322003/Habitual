import 'package:flutter/material.dart';

import '../../data/habitual_repository.dart';
import 'day_time_grid_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.repository,
  });

  final HabitualRepository repository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDate = DateTime.now();
  }

  void _goToMonth(int offset) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final firstWeekday = firstDay.weekday; // Mon=1..Sun=7
    final mondayOffset = firstWeekday - 1; // Mon=0..Sun=6

    final cells = List.generate(42, (i) {
      final day = firstDay.add(Duration(days: i - mondayOffset));
      return DateTime(day.year, day.month, day.day);
    });

    final today = DateTime.now();

    String monthLabel =
        '${_focusedMonth.month.toString().padLeft(2, '0')}/${_focusedMonth.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
                _selectedDate = DateTime.now();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _goToMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      monthLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => _goToMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _WeekdayRow(),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: cells.length,
              itemBuilder: (context, i) {
                final d = cells[i];
                final isInMonth = d.month == month;
                final isSelected = d.year == _selectedDate.year &&
                    d.month == _selectedDate.month &&
                    d.day == _selectedDate.day;
                final isToday = d.year == today.year &&
                    d.month == today.month &&
                    d.day == today.day;

                final bgColor = isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent;

                final fgColor = isInMonth
                    ? null
                    : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5);

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    setState(() => _selectedDate = d);
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DayTimeGridScreen(
                          repository: widget.repository,
                          date: d,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${d.day}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: fgColor,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    final days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(7, (i) {
          return Expanded(
            child: Center(
              child: Text(
                days[i],
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          );
        }),
      ),
    );
  }
}

