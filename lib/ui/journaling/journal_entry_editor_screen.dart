import 'package:flutter/material.dart';

import '../../data/habitual_repository.dart';
import '../../data/models.dart';
import 'two_d_slider.dart';

class JournalEntryEditorScreen extends StatefulWidget {
  const JournalEntryEditorScreen({
    super.key,
    required this.repository,
    required this.occurrence,
  });

  final HabitualRepository repository;
  final PlanOccurrence occurrence;

  @override
  State<JournalEntryEditorScreen> createState() =>
      _JournalEntryEditorScreenState();
}

class _JournalEntryEditorScreenState extends State<JournalEntryEditorScreen> {
  late final TextEditingController _notesController;
  double _enjoyment = 5;
  double _rewarding = 5;
  bool _hasPoint = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.repository.getJournalEntry(
      widget.occurrence.planId,
      widget.occurrence.occurrenceDateYmd,
    );
    _notesController = TextEditingController(text: existing?.content ?? '');

    final e = existing?.energy;
    final r = existing?.rewarding;
    if (e != null && r != null) {
      _enjoyment = e.clamp(0, 10);
      _rewarding = r.clamp(0, 10);
      _hasPoint = true;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final content = _notesController.text.trim();
    if (content.isEmpty) return;

    setState(() => _saving = true);
    await widget.repository.upsertJournalEntry(
      planId: widget.occurrence.planId,
      occurrenceDateYmd: widget.occurrence.occurrenceDateYmd,
      content: content,
      energy: _hasPoint ? _enjoyment : null,
      rewarding: _hasPoint ? _rewarding : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    await widget.repository.deleteJournalEntry(
      planId: widget.occurrence.planId,
      occurrenceDateYmd: widget.occurrence.occurrenceDateYmd,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.repository.getJournalEntry(
      widget.occurrence.planId,
      widget.occurrence.occurrenceDateYmd,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          if (existing != null)
            IconButton(
              tooltip: 'Delete entry',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Delete journal entry?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                      if (ok == true) {
                        await _delete();
                      }
                    },
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.occurrence.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatTime(widget.occurrence.startTimeMinutes)} - ${_formatTime(widget.occurrence.endTimeMinutes)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 18),
            Text(
              'Enjoyment (X) vs Rewarding (Y)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TwoDAxisSlider(
              xLabel: 'Enjoyment',
              yLabel: 'Rewarding',
              xMinLabel: 'wanna run away',
              xMaxLabel: 'give me more',
              yMinLabel: 'here we go again',
              yMaxLabel: 'super exciting',
              xMin: 0,
              xMax: 10,
              yMin: 0,
              yMax: 10,
              xValue: _enjoyment,
              yValue: _rewarding,
              hasValue: _hasPoint,
              onChanged: (x, y) {
                setState(() {
                  _enjoyment = x;
                  _rewarding = y;
                  _hasPoint = true;
                });
              },
              onClear: () {
                setState(() {
                  _hasPoint = false;
                });
              },
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _notesController,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

