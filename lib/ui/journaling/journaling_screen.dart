import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/habitual_repository.dart';
import '../../data/models.dart';
import 'journal_entry_editor_screen.dart';

class JournalingScreen extends StatefulWidget {
  const JournalingScreen({
    super.key,
    required this.repository,
  });

  final HabitualRepository repository;

  @override
  State<JournalingScreen> createState() => _JournalingScreenState();
}

class _JournalingScreenState extends State<JournalingScreen> {
  late DateTime _selectedDate;
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime _todayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _openJournalEditor({
    required PlanOccurrence occurrence,
    required bool isNew,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => JournalEntryEditorScreen(
          repository: widget.repository,
          occurrence: occurrence,
        ),
      ),
    );

    if (!mounted) return;
    if (changed == true) setState(() {});
  }

  Future<void> _refresh() async {
    // For MVP the UI computes occurrences synchronously from repository.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final occurrences = widget.repository.getOccurrencesForDate(_selectedDate);
    final today = _todayOnly(DateTime.now());
    final selected = _todayOnly(_selectedDate);
    final nowMinutes = minutesOfDayFromHoursAndMinutes(_now.hour, _now.minute);

    final current = (selected == today)
        ? pickCurrentOccurrence(
            occurrencesForDate: occurrences,
            now: _now,
          )
        : null;

    final journalByOccurrenceKey = <String, JournalEntry?>{};
    for (final o in occurrences) {
      journalByOccurrenceKey['${o.planId}|${o.occurrenceDateYmd}'] =
          widget.repository.getJournalEntry(o.planId, o.occurrenceDateYmd);
    }

    List<PlanOccurrence> missed;
    List<PlanOccurrence> journalled;

    if (selected.isBefore(today)) {
      missed = occurrences
          .where((o) =>
              journalByOccurrenceKey['${o.planId}|${o.occurrenceDateYmd}'] ==
              null)
          .toList();
      journalled = occurrences
          .where((o) =>
              journalByOccurrenceKey['${o.planId}|${o.occurrenceDateYmd}'] !=
              null)
          .toList();
    } else {
      // selected == today for now (ignore future).
      missed = occurrences
          .where((o) {
            final entry = journalByOccurrenceKey['${o.planId}|${o.occurrenceDateYmd}'];
            if (entry != null) return false;
            return o.endTimeMinutes <= nowMinutes;
          })
          .toList();
      journalled = occurrences
          .where((o) {
            final entry = journalByOccurrenceKey['${o.planId}|${o.occurrenceDateYmd}'];
            return entry != null;
          })
          .toList();
    }

    String formatDateShort(DateTime d) {
      final y = d.year.toString();
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journaling'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date: ${formatDateShort(_selectedDate)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Now: ${_now.hour.toString().padLeft(2, '0')}:${(_now.minute).toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 1));
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (current != null) _CurrentTaskCard(occurrence: current, onJournal: () async {
                    await _openJournalEditor(occurrence: current, isNew: journalByOccurrenceKey['${current.planId}|${current.occurrenceDateYmd}'] == null);
                    await _refresh();
                  }),
                  if (current == null && selected == today)
                    _EmptyCurrentTask(onJournal: null),
                  const SizedBox(height: 16),
                  Text('Missed / not journalled', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (missed.isEmpty)
                    const Text('Nothing to journal for this date.'),
                  for (final o in missed)
                    _OccurrenceRow(
                      occurrence: o,
                      entry: journalByOccurrenceKey['${o.planId}|${o.occurrenceDateYmd}'],
                      isNew: true,
                      onTapJournal: () async {
                        await _openJournalEditor(occurrence: o, isNew: true);
                        await _refresh();
                      },
                    ),
                  const SizedBox(height: 16),
                  Text('Already journalled', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (journalled.isEmpty)
                    const Text('No entries saved yet.'),
                  for (final o in journalled)
                    _OccurrenceRow(
                      occurrence: o,
                      entry: journalByOccurrenceKey['${o.planId}|${o.occurrenceDateYmd}'],
                      isNew: false,
                      onTapJournal: () async {
                        await _openJournalEditor(occurrence: o, isNew: false);
                        await _refresh();
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentTaskCard extends StatelessWidget {
  const _CurrentTaskCard({
    required this.occurrence,
    required this.onJournal,
  });

  final PlanOccurrence occurrence;
  final Future<void> Function() onJournal;

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current task', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(
              occurrence.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatTime(occurrence.startTimeMinutes)} - ${_formatTime(occurrence.endTimeMinutes)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {
                  onJournal();
                },
                child: const Text('Journal now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCurrentTask extends StatelessWidget {
  const _EmptyCurrentTask({required this.onJournal});

  final Future<void> Function()? onJournal;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No active task right now.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _OccurrenceRow extends StatelessWidget {
  const _OccurrenceRow({
    required this.occurrence,
    required this.entry,
    required this.isNew,
    required this.onTapJournal,
  });

  final PlanOccurrence occurrence;
  final JournalEntry? entry;
  final bool isNew;
  final Future<void> Function() onTapJournal;

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(occurrence.title),
        subtitle: Text(
          '${_formatTime(occurrence.startTimeMinutes)} - ${_formatTime(occurrence.endTimeMinutes)}'
          '${entry == null ? '' : ' • saved'}',
        ),
        trailing: FilledButton(
          onPressed: () {
            onTapJournal();
          },
          child: Text(isNew ? 'Journal' : 'Edit'),
        ),
      ),
    );
  }
}

