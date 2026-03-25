import 'package:flutter/material.dart';

import '../../data/habitual_repository.dart';
import '../../data/models.dart';
import 'add_activity_sheet.dart';

class DayTimeGridScreen extends StatefulWidget {
  const DayTimeGridScreen({
    super.key,
    required this.repository,
    required this.date,
  });

  static const int minutesPerSlot = 15;
  static const int slotsPerDay = 24 * 60 ~/ minutesPerSlot;

  final HabitualRepository repository;
  final DateTime date;

  @override
  State<DayTimeGridScreen> createState() => _DayTimeGridScreenState();
}

class _DayTimeGridScreenState extends State<DayTimeGridScreen> {
  List<PlanOccurrence> _occurrences = const [];

  final ScrollController _scrollController = ScrollController();
  bool _didInitialScroll = false;

  String? _draggingKey;
  int? _dragPreviewStartMinutes;
  int? _dragBaseStartMinutes;
  double _dragTotalDyPx = 0;
  bool _isDraggingBlock = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _occurrenceKey(PlanOccurrence o) => '${o.planId}|${o.occurrenceDateYmd}';

  Future<void> _refresh() async {
    final items = widget.repository.getOccurrencesForDate(widget.date);
    setState(() {
      _occurrences = items;
    });
  }

  int _snapMinutesToGrid(int minutes) {
    return (minutes / DayTimeGridScreen.minutesPerSlot).round() *
        DayTimeGridScreen.minutesPerSlot;
  }

  int _clampStartMinutes(int startMinutes, int durationMinutes) {
    final latest = 24 * 60 - durationMinutes;
    return startMinutes.clamp(0, latest);
  }

  String _formatYmdHuman(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _openAddSheet({required int startTimeMinutes}) async {
    final startYmd = ymd(widget.date);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddActivitySheet(
        repository: widget.repository,
        initialDateYmd: startYmd,
        initialStartTimeMinutes: _snapMinutesToGrid(startTimeMinutes),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  int _minutesFromLocalDyWithSlotHeight({
    required double dy,
    required double slotHeight,
  }) {
    final clampedDy = dy.clamp(
      0,
      DayTimeGridScreen.slotsPerDay * slotHeight - 0.001,
    );
    final slotIndex = (clampedDy / slotHeight).floor();
    return slotIndex * DayTimeGridScreen.minutesPerSlot;
  }

  @override
  Widget build(BuildContext context) {
    final y = ymd(widget.date);
    return Scaffold(
      appBar: AppBar(
        title: Text('Day $y'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatYmdHuman(widget.date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add activity',
                    icon: const Icon(Icons.add),
                    onPressed: () => _openAddSheet(startTimeMinutes: 9 * 60),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Zoom level: show about 5 hours in the visible viewport.
                  const visibleHours = 5;
                  final visibleSlots =
                      (visibleHours * 60 ~/ DayTimeGridScreen.minutesPerSlot);
                  final slotHeight = (constraints.maxHeight / visibleSlots)
                      .clamp(10.0, 26.0);

                  final totalHeight =
                      DayTimeGridScreen.slotsPerDay * slotHeight;

                  if (!_didInitialScroll && _scrollController.hasClients) {
                    _didInitialScroll = true;
                    // Start around 7am.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      if (!_scrollController.hasClients) return;
                      _scrollController.jumpTo(
                        (7 * 60 / DayTimeGridScreen.minutesPerSlot) * slotHeight,
                      );
                    });
                  }

                  return Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: _isDraggingBlock
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 56,
                            height: totalHeight,
                            child: _HourLabels(slotHeight: slotHeight),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: totalHeight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (d) async {
                                  final minutes = _minutesFromLocalDyWithSlotHeight(
                                    dy: d.localPosition.dy,
                                    slotHeight: slotHeight,
                                  );
                                  await _openAddSheet(startTimeMinutes: minutes);
                                },
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _GridPainter(
                                          slotHeight: slotHeight,
                                        ),
                                      ),
                                    ),
                                    for (final o in _occurrences)
                                      _buildOccurrenceBlock(o, slotHeight: slotHeight),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOccurrenceBlock(PlanOccurrence o, {required double slotHeight}) {
    final key = _occurrenceKey(o);
    final effectiveStart = (_draggingKey == key && _dragPreviewStartMinutes != null)
        ? _dragPreviewStartMinutes!
        : o.startTimeMinutes;

    final top = (effectiveStart ~/ DayTimeGridScreen.minutesPerSlot) *
        slotHeight;
    final height = (o.durationMinutes ~/ DayTimeGridScreen.minutesPerSlot) *
        slotHeight;

    final colors = [
      Colors.deepPurpleAccent,
      Colors.green,
      Colors.orangeAccent,
      Colors.blueAccent,
      Colors.pinkAccent,
      Colors.cyanAccent,
    ];
    final color = colors[o.planId.hashCode.abs() % colors.length];

    return Positioned(
      left: 6,
      right: 6,
      top: top,
      height: height,
      child: _DraggableActivityBlock(
        title: o.title,
        startMinutes: effectiveStart,
        endMinutes: effectiveStart + o.durationMinutes,
        color: color,
        onTap: () async {
          await _openEditSheet(occurrence: o);
          if (!mounted) return;
          await _refresh();
        },
        onHandlePointerDown: () {
          // Disable timeline scrolling immediately when the user touches the handle,
          // so the scroll view doesn't compete in the gesture arena.
          if (_isDraggingBlock) return;
          setState(() {
            _isDraggingBlock = true;
          });
        },
        onHandlePointerUpOrCancel: () {
          // Re-enable scrolling if a drag didn't actually start.
          if (_draggingKey != null) return;
          if (!_isDraggingBlock) return;
          setState(() {
            _isDraggingBlock = false;
          });
        },
        onPanStart: () {
          setState(() {
            _draggingKey = key;
            _dragPreviewStartMinutes = effectiveStart;
            _dragBaseStartMinutes = effectiveStart;
            _dragTotalDyPx = 0;
            _isDraggingBlock = true;
          });
        },
        onPanUpdate: (deltaDyPx) {
          if (_draggingKey != key || _dragPreviewStartMinutes == null) return;
          _dragTotalDyPx += deltaDyPx;
          final base = _dragBaseStartMinutes ?? _dragPreviewStartMinutes!;
          final deltaMinutes = (_dragTotalDyPx / slotHeight) *
              DayTimeGridScreen.minutesPerSlot;
          final newMinutes = base + deltaMinutes.round();
          final snapped = _snapMinutesToGrid(newMinutes);
          final clamped = _clampStartMinutes(snapped, o.durationMinutes);
          setState(() {
            _dragPreviewStartMinutes = clamped;
          });
        },
        onPanEnd: () async {
          if (_draggingKey != key || _dragPreviewStartMinutes == null) return;
          final newStart = _dragPreviewStartMinutes!;

          setState(() {
            _draggingKey = null;
            _dragPreviewStartMinutes = null;
            _dragBaseStartMinutes = null;
            _dragTotalDyPx = 0;
            _isDraggingBlock = false;
          });

          await widget.repository.setOverride(
            planId: o.planId,
            occurrenceDateYmd: o.occurrenceDateYmd,
            overrideStartTimeMinutes: newStart,
            isDeleted: false,
          );
          await _refresh();
        },
      ),
    );
  }

  Future<void> _openEditSheet({required PlanOccurrence occurrence}) async {
    final plan = widget.repository.getPlanById(occurrence.planId);
    if (plan == null) return;

    final startMinutesEffective = occurrence.startTimeMinutes;
    final titleController = TextEditingController(text: plan.title);
    int durationMinutes = plan.durationMinutes;
    int startMinutes = startMinutesEffective;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        String formatTime(int minutes) {
          final h = minutes ~/ 60;
          final m = minutes % 60;
          return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        }

        Future<void> pickStart() async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: startMinutes ~/ 60,
              minute: startMinutes % 60,
            ),
          );
          if (picked == null) return;
          final snapped = ((picked.minute / 15).round() * 15);
          startMinutes = (picked.hour * 60 + snapped).clamp(0, 24 * 60 - 15);
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Activity', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule),
                              label: Text(formatTime(startMinutes)),
                              onPressed: () async {
                                await pickStart();
                                setSheetState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: durationMinutes,
                            items: const [15, 30, 45, 60, 90]
                                .map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text('${v} min'),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setSheetState(() {
                                durationMinutes = v;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          final newTitle = titleController.text.trim();
                          if (newTitle.isEmpty) return;

                          await widget.repository.upsertPlan(
                            planId: plan.id,
                            title: newTitle,
                            durationMinutes: durationMinutes,
                            startTimeMinutes: plan.startTimeMinutes,
                            recurrenceWeekdays: plan.recurrenceWeekdays,
                            startDateYmd: plan.startDateYmd,
                            untilDateYmd: plan.untilDateYmd,
                          );

                          await widget.repository.setOverride(
                            planId: plan.id,
                            occurrenceDateYmd: occurrence.occurrenceDateYmd,
                            overrideStartTimeMinutes: startMinutes,
                            isDeleted: false,
                          );

                          Navigator.of(context).pop();
                        },
                        child: const Text('Save'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () async {
                          await widget.repository.setOverride(
                            planId: plan.id,
                            occurrenceDateYmd: occurrence.occurrenceDateYmd,
                            overrideStartTimeMinutes: startMinutes,
                            isDeleted: true,
                          );
                          Navigator.of(context).pop();
                        },
                        child: const Text('Remove for this day'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HourLabels extends StatelessWidget {
  const _HourLabels({
    required this.slotHeight,
  });

  final double slotHeight;

  @override
  Widget build(BuildContext context) {
    // One hour == 4 slots (60/15).
    const slotsPerHour = 60 ~/ DayTimeGridScreen.minutesPerSlot;
    return Column(
      children: List.generate(24, (hour) {
        final label = '${hour.toString().padLeft(2, '0')}:00';
        return SizedBox(
          height: slotsPerHour * slotHeight,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.slotHeight});

  final double slotHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;
    final strongPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 1;

    final totalSlots = DayTimeGridScreen.slotsPerDay;
    for (int i = 0; i <= totalSlots; i++) {
      final y = i * slotHeight;
      final isHour = i % 4 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isHour ? strongPaint : linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DraggableActivityBlock extends StatefulWidget {
  const _DraggableActivityBlock({
    required this.title,
    required this.startMinutes,
    required this.endMinutes,
    required this.color,
    required this.onTap,
    required this.onHandlePointerDown,
    required this.onHandlePointerUpOrCancel,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final String title;
  final int startMinutes;
  final int endMinutes;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onHandlePointerDown;
  final VoidCallback onHandlePointerUpOrCancel;
  final VoidCallback onPanStart;
  final ValueChanged<double> onPanUpdate;
  final VoidCallback onPanEnd;

  @override
  State<_DraggableActivityBlock> createState() => _DraggableActivityBlockState();
}

class _DraggableActivityBlockState extends State<_DraggableActivityBlock> {
  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.85),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main body: tap to edit, no dragging here.
            Expanded(
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Avoid overflow for short events (e.g. 15 minutes).
                      final isVeryShort = constraints.maxHeight < 28;
                      final verticalPadding = isVeryShort ? 2.0 : 6.0;

                      final timeText = Text(
                        _formatTime(widget.startMinutes),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                      );

                      final titleText = Text(
                        widget.title,
                        maxLines: isVeryShort ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              height: 1.05,
                            ),
                      );

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: verticalPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            timeText,
                            if (!isVeryShort) const SizedBox(height: 2),
                            Flexible(child: titleText),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Grab handle: ONLY place that can start a drag.
            _DragHandle(
              onPointerDown: widget.onHandlePointerDown,
              onPointerUpOrCancel: widget.onHandlePointerUpOrCancel,
              onPanStart: widget.onPanStart,
              onPanUpdate: widget.onPanUpdate,
              onPanEnd: widget.onPanEnd,
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.onPointerDown,
    required this.onPointerUpOrCancel,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final VoidCallback onPointerDown;
  final VoidCallback onPointerUpOrCancel;
  final VoidCallback onPanStart;
  final ValueChanged<double> onPanUpdate;
  final VoidCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPointerDown(),
      onPointerUp: (_) => onPointerUpOrCancel(),
      onPointerCancel: (_) => onPointerUpOrCancel(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onPanStart(),
        onPanUpdate: (d) => onPanUpdate(d.delta.dy),
        onPanEnd: (_) => onPanEnd(),
        child: Container(
          width: 26,
          alignment: Alignment.center,
          color: Colors.white.withOpacity(0.12),
          child: Icon(
            Icons.drag_indicator,
            size: 18,
            color: Colors.white.withOpacity(0.95),
          ),
        ),
      ),
    );
  }
}

