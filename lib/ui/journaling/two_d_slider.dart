import 'package:flutter/material.dart';

typedef TwoDChanged = void Function(double x, double y);

class TwoDAxisSlider extends StatelessWidget {
  const TwoDAxisSlider({
    super.key,
    required this.xLabel,
    required this.yLabel,
    required this.xMinLabel,
    required this.xMaxLabel,
    required this.yMinLabel,
    required this.yMaxLabel,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.xValue,
    required this.yValue,
    required this.hasValue,
    required this.onChanged,
    required this.onClear,
  });

  final String xLabel;
  final String yLabel;

  /// Labels at the ends of X axis (min -> max).
  final String xMinLabel;
  final String xMaxLabel;

  /// Labels at the ends of Y axis (min -> max).
  final String yMinLabel;
  final String yMaxLabel;

  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;

  final double xValue;
  final double yValue;
  final bool hasValue;

  final TwoDChanged onChanged;
  final VoidCallback onClear;

  double _clamp(double v, double min, double max) => v.clamp(min, max).toDouble();

  // Convert position inside square (0..1) to value.
  double _lerp(double t, double a, double b) => a + (b - a) * t;

  // Convert value to normalized (0..1).
  double _invLerp(double v, double a, double b) {
    if ((b - a).abs() < 0.000001) return 0;
    return ((v - a) / (b - a)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Reserve space for axes labels around the square.
            const leftGutter = 72.0;
            const bottomGutter = 44.0;
            final side = (constraints.maxWidth - leftGutter)
                .clamp(180.0, constraints.maxWidth - leftGutter);

            final squareSize = Size(side, side);

            void updateFromOffset(Offset localInSquare) {
              final dx =
                  (localInSquare.dx / squareSize.width).clamp(0.0, 1.0);
              final dy =
                  (localInSquare.dy / squareSize.height).clamp(0.0, 1.0);

              final x = _lerp(dx, xMin, xMax);
              // Y axis: top = max, bottom = min.
              final y = _lerp(1 - dy, yMin, yMax);

              onChanged(
                _clamp(x, xMin, xMax),
                _clamp(y, yMin, yMax),
              );
            }

            final nx = _invLerp(xValue, xMin, xMax);
            final ny = _invLerp(yValue, yMin, yMax);
            final handle = Offset(
              nx * squareSize.width,
              (1 - ny) * squareSize.height,
            );

            return SizedBox(
              height: squareSize.height + bottomGutter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: leftGutter,
                    height: squareSize.height,
                    child: _YAxisLabels(
                      axisLabel: yLabel,
                      topLabel: yMaxLabel,
                      bottomLabel: yMinLabel,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: squareSize.width,
                        height: squareSize.height,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => updateFromOffset(d.localPosition),
                          onPanStart: (d) => updateFromOffset(d.localPosition),
                          onPanUpdate: (d) => updateFromOffset(d.localPosition),
                          child: CustomPaint(
                            painter: _TwoDPainter(
                              colorScheme: cs,
                              hasValue: hasValue,
                              handle: handle,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: squareSize.width,
                        height: bottomGutter,
                        child: _XAxisLabels(
                          axisLabel: xLabel,
                          leftLabel: xMinLabel,
                          rightLabel: xMaxLabel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                '$xLabel: ${xValue.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Expanded(
              child: Text(
                '$yLabel: ${yValue.toStringAsFixed(1)}',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Tap or drag to set both.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            TextButton(
              onPressed: hasValue ? onClear : null,
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TwoDPainter extends CustomPainter {
  _TwoDPainter({
    required this.colorScheme,
    required this.hasValue,
    required this.handle,
  });

  final ColorScheme colorScheme;
  final bool hasValue;
  final Offset handle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          colorScheme.surfaceContainerHighest,
          colorScheme.primaryContainer,
        ],
      ).createShader(rect);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colorScheme.outlineVariant;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colorScheme.outlineVariant.withOpacity(0.35);

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas.drawRRect(rrect, bg);
    canvas.drawRRect(rrect, border);

    // Axis lines (left and bottom), inside the square.
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colorScheme.outline;
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);

    // 5x5 grid
    for (int i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      final y = size.height * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (hasValue) {
      final shadow = Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(handle.translate(0, 1), 9, shadow);

      final dot = Paint()..color = colorScheme.primary;
      final dotBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.95);
      canvas.drawCircle(handle, 8, dot);
      canvas.drawCircle(handle, 8, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _TwoDPainter oldDelegate) {
    return oldDelegate.hasValue != hasValue || oldDelegate.handle != handle;
  }
}

class _XAxisLabels extends StatelessWidget {
  const _XAxisLabels({
    required this.axisLabel,
    required this.leftLabel,
    required this.rightLabel,
  });

  final String axisLabel;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final axisStyle = Theme.of(context).textTheme.labelMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Text(axisLabel, style: axisStyle)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text(leftLabel, style: style)),
            Expanded(
              child: Text(
                rightLabel,
                style: style,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _YAxisLabels extends StatelessWidget {
  const _YAxisLabels({
    required this.axisLabel,
    required this.topLabel,
    required this.bottomLabel,
  });

  final String axisLabel;
  final String topLabel;
  final String bottomLabel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final axisStyle = Theme.of(context).textTheme.labelMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(topLabel, style: style, maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        RotatedBox(
          quarterTurns: 3,
          child: Center(child: Text(axisLabel, style: axisStyle)),
        ),
        const Spacer(),
        Text(bottomLabel, style: style, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

