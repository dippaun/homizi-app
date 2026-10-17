import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/owner/owner_models.dart';

/// Bar chart drawn with a painter. No chart package and no network.
class ListingStatsChart extends StatelessWidget {
  const ListingStatsChart({required this.days, super.key});

  final List<DayCount> days;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('listing-stats-chart'),
      height: 200,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarsPainter(
          days: days,
          bar: HomiziColors.accent,
          grid: HomiziColors.line,
          label: HomiziColors.muted,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.days,
    required this.bar,
    required this.grid,
    required this.label,
  });

  final List<DayCount> days;
  final Color bar;
  final Color grid;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    const labelBand = 22.0;
    final chart = Rect.fromLTWH(0, 8, size.width, size.height - labelBand - 8);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      gridPaint,
    );
    if (days.isEmpty) {
      return;
    }
    var peak = 1;
    for (final day in days) {
      if (day.views > peak) {
        peak = day.views;
      }
    }
    final slot = chart.width / days.length;
    final barWidth = (slot * 0.62).clamp(2.0, 18.0);
    final fill = Paint()..color = bar;
    for (var index = 0; index < days.length; index++) {
      final views = days[index].views;
      final height = chart.height * (views / peak);
      final left = chart.left + slot * index + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, chart.bottom - height, barWidth, height),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, fill);
    }
    final style = TextStyle(color: label, fontSize: 11);
    final indexes = <int>{0, days.length - 1};
    if (days.length > 8) {
      indexes.add(days.length ~/ 2);
    }
    for (final index in indexes) {
      if (index < 0 || index >= days.length) {
        continue;
      }
      final text = TextPainter(
        text: TextSpan(text: '${days[index].day.day}', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (chart.left + slot * index + slot / 2 - text.width / 2).clamp(
        0.0,
        size.width - text.width,
      );
      text.paint(canvas, Offset(dx, chart.bottom + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) {
    return oldDelegate.days != days || oldDelegate.bar != bar;
  }
}
