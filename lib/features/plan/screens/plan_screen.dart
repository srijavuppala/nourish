import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../shared/widgets/item_cards.dart';
import '../data/meal_parser_service.dart';
import '../data/plan_repository.dart';
import '../models/meal_item.dart';
import '../models/plan_meal.dart';

/// Everything the user told us during onboarding, editable. Changes here apply
/// to every future check-in.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(planMealsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Plan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addByChat(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add meal'),
      ),
      body: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load your plan.')),
        data: (meals) {
          if (meals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your meals live here',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Describe a meal once and your check-in is built from it '
                      'every day after.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Grouped by slot, in the order the day runs.
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              for (final slot in MealSlot.values)
                if (meals.any((meal) => meal.slot == slot)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                    child: Text(
                      slot.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final meal in meals.where((meal) => meal.slot == slot))
                    _MealCard(meal: meal),
                ],
            ],
          );
        },
      ),
    );
  }

  /// Adding a meal reuses the same parser as onboarding, so there is one way
  /// to describe food in the whole app.
  Future<void> _addByChat(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<({MealSlot slot, List<MealItem> items})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddMealSheet(),
    );
    if (result == null) return;

    final repository = ref.read(planRepositoryProvider);
    if (repository == null) return;

    await repository.addMeal(
      slot: result.slot,
      label: 'My ${result.slot.label.toLowerCase()}',
      items: result.items,
      source: 'chat',
    );
  }
}

class _MealCard extends ConsumerWidget {
  const _MealCard({required this.meal});

  final PlanMeal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meal.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete ${meal.label}',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
              for (final item in meal.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.display)),
                      Text(
                        '${item.kcal.round()} kcal · ${item.proteinG.round()}g',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20),
              Text(
                '${meal.kcal.round()} kcal · ${meal.proteinG.round()}g protein',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${meal.label}?'),
        content: const Text(
          'It will stop appearing in your daily check-in. Days you already '
          'logged are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(planRepositoryProvider)?.deleteMeal(meal.id);
  }
}

/// Describe a meal in plain language, confirm the parsed items, save.
class _AddMealSheet extends ConsumerStatefulWidget {
  const _AddMealSheet();

  @override
  ConsumerState<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<_AddMealSheet> {
  final _input = TextEditingController();
  MealSlot _slot = MealSlot.breakfast;
  List<MealItem>? _items;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final result = await ref.read(mealParserProvider).parse(text, slot: _slot);
      if (!mounted) return;
      setState(() {
        _items = result.items.isEmpty ? null : result.items;
        _message = result.isEmpty || result.needsClarification
            ? result.question
            : null;
      });
    } on MealParseException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a meal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SegmentedButton<MealSlot>(
            segments: [
              for (final slot in MealSlot.values)
                ButtonSegment(value: slot, label: Text(slot.label)),
            ],
            selected: {_slot},
            onSelectionChanged: (selection) =>
                setState(() => _slot = selection.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            enabled: !_busy,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _parse(),
            decoration: const InputDecoration(
              hintText: 'e.g. six eggs and two bananas',
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          if (items == null)
            FilledButton(
              onPressed: _busy ? null : _parse,
              child: Text(_busy ? 'Reading…' : 'Continue'),
            )
          else
            ConfirmItemCards(
              items: items,
              onChanged: (next) => setState(() => _items = next),
              onConfirm: () =>
                  Navigator.pop(context, (slot: _slot, items: items)),
            ),
        ],
      ),
    );
  }
}
