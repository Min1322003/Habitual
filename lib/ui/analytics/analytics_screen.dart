import 'package:flutter/material.dart';

import '../../data/habitual_repository.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, required this.repository});

  final HabitualRepository repository;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final counts = days
        .map((d) => repository.getJournalEntriesForDate(d).length)
        .toList();

    final total = counts.fold<int>(0, (a, b) => a + b);
    final maxCount = counts.isEmpty ? 1 : (counts.reduce((a, b) => a > b ? a : b));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text('Journal Summary', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Total entries (last 7 days): $total'),
              const SizedBox(height: 18),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Entries per day', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      for (int i = 0; i < days.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _DayBar(
                            date: days[i],
                            count: counts[i],
                            maxCount: maxCount,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Next up: trends per task + cognitive load charts once you add that metric.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.date,
    required this.count,
    required this.maxCount,
  });

  final DateTime date;
  final int count;
  final int maxCount;

  String _dayLabel(DateTime d) {
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount <= 0 ? 0.0 : (count / maxCount);
    final maxWidth = MediaQuery.of(context).size.width - 120;
    final width =
        (maxWidth * fraction).clamp(0.0, maxWidth).toDouble();

    return Row(
      children: [
        SizedBox(width: 70, child: Text(_dayLabel(date))),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: width,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(count.toString()),
      ],
    );
  }
}

