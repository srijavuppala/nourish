import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

/// A progress ring, always labelled with both numbers so the figure is never
/// ambiguous — "98 of 140g protein", not "70%".
class NutrientRing extends StatelessWidget {
  const NutrientRing({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    super.key,
  });

  final String label;
  final double value;
  final int target;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Over target still fills the ring rather than wrapping around it.
    final progress = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);

    return Semantics(
      label: '$label: ${value.round()} of $target $unit',
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 54,
            lineWidth: 11,
            percent: progress,
            animation: true,
            animationDuration: 600,
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.round()}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'of $target',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}
