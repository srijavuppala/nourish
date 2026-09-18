import 'package:flutter/material.dart';

import '../../features/plan/models/meal_item.dart';

/// The parsed items, shown for correction before anything is saved. Nothing
/// the AI produced reaches the plan without passing through here.
class ConfirmItemCards extends StatelessWidget {
  const ConfirmItemCards({
    required this.items,
    required this.onChanged,
    required this.onConfirm,
    super.key,
  });

  final List<MealItem> items;
  final ValueChanged<List<MealItem>> onChanged;
  final VoidCallback? onConfirm;

  void _setQty(int index, double qty) {
    final next = [...items];
    if (qty <= 0) {
      next.removeAt(index);
    } else {
      next[index] = next[index].withQty(qty);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = items.fold<double>(0, (sum, item) => sum + item.kcal);
    final protein = items.fold<double>(0, (sum, item) => sum + item.proteinG);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < items.length; index++)
              _ItemRow(
                item: items[index],
                onQtyChanged: (qty) => _setQty(index, qty),
              ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${kcal.round()} kcal · ${protein.round()}g protein',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Estimates, not medical advice.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onConfirm,
              child: const Text('Looks right, save it'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onQtyChanged});

  final MealItem item;
  final ValueChanged<double> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Whole-number foods step by 1; weighed ones by a useful fraction.
    final step = item.qty >= 10 ? 10.0 : 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.display,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item.kcal.round()} kcal · ${item.proteinG.round()}g protein',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onQtyChanged(item.qty - step),
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Less ${item.name}',
          ),
          IconButton(
            onPressed: () => onQtyChanged(item.qty + step),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'More ${item.name}',
          ),
        ],
      ),
    );
  }
}
