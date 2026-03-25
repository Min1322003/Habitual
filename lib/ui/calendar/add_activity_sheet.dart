import 'package:flutter/material.dart';

import '../../data/habitual_repository.dart';
import '../../data/models.dart';

class AddActivitySheet extends StatefulWidget {
  const AddActivitySheet({
    super.key,
    required this.repository,
    required this.initialDateYmd,
    required this.initialStartTimeMinutes,
  });

  final HabitualRepository repository;
  final String initialDateYmd;
  final int initialStartTimeMinutes;

  @override
  State<AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<AddActivitySheet> {
  final _titleController = TextEditingController();
  late int _startTimeMinutes;
  int _durationMinutes = 30;

  bool _repeatWeekly = true;
  final Set<int> _weekdays = <int>{};
  // 1..7: Mon..Sun
  final _untilEnabled = false;
  DateTime? _untilDate;

  @override
  void initState() {
    super.initState();
    _startTimeMinutes = widget.initialStartTimeMinutes;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  TimeOfDay _timeOfDayFromMinutes(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  Future<void> _pickStartTime() async {
    final initial = _timeOfDayFromMinutes(_startTimeMinutes);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;

    // Snap to 15 minutes.
    final snappedRaw = (picked.minute / 15).round() * 15;
    final snapped = snappedRaw.clamp(0, 60).toInt();
    setState(() {
      _startTimeMinutes = picked.hour * 60 + snapped;
    });
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final weekdayLabels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final theme = Theme.of(context);

    final untilDateYmd = _untilEnabled && _untilDate != null ? ymd(_untilDate!) : null;

    final canSave = _titleController.text.trim().isNotEmpty &&
        _durationMinutes > 0 &&
        (!_repeatWeekly || _weekdays.isNotEmpty);

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Activity',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(_formatTime(_startTimeMinutes)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: _durationMinutes,
                    items: const [15, 30, 45, 60, 90]
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text('${v} min'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _durationMinutes = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Repeat weekly'),
                value: _repeatWeekly,
                onChanged: (v) {
                  setState(() {
                    _repeatWeekly = v;
                    if (!_repeatWeekly) _weekdays.clear();
                  });
                },
              ),
              if (_repeatWeekly) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final weekday = i + 1; // Mon=1..Sun=7
                    final selected = _weekdays.contains(weekday);
                    return FilterChip(
                      label: Text(weekdayLabels[i]),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _weekdays.add(weekday);
                          } else {
                            _weekdays.remove(weekday);
                          }
                        });
                      },
                    );
                  }),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canSave
                    ? () async {
                        final title = _titleController.text.trim();
                        final recurrenceWeekdays = _repeatWeekly
                            ? (() {
                                final list = _weekdays.toList();
                                list.sort();
                                return list;
                              })()
                            : <int>[];
                        await widget.repository.upsertPlan(
                          planId: null,
                          title: title,
                          durationMinutes: _durationMinutes,
                          startTimeMinutes: _startTimeMinutes,
                          recurrenceWeekdays: recurrenceWeekdays,
                          startDateYmd: widget.initialDateYmd,
                          untilDateYmd: untilDateYmd,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    : null,
                child: const Text('Save'),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

