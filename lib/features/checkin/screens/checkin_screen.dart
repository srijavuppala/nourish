import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/router.dart';
import '../../plan/data/plan_repository.dart';
import '../../plan/models/meal_item.dart';
import '../../plan/models/plan_meal.dart';
import '../data/checkin_repository.dart';
import '../models/day_log.dart';

/// The swipe deck. Right for yes, left for no, stepper to adjust the amount.
/// One question per card, and the whole thing finishes in under 30 seconds.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final _controller = CardSwiperController();

  /// Per-meal answers, keyed by meal id. Adjusted quantities live here until
  /// the deck finishes, so nothing is written mid-swipe.
  final Map<String, List<MealItem>> _adjusted = {};
  final Map<String, MealStatus> _statuses = {};

  bool _workout = false;
  int _waterGlasses = 0;
  bool _finished = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _answerMeal(PlanMeal meal, {required bool ate}) {
    final adjusted = _adjusted[meal.id];
    final partial = adjusted != null && _isReduced(meal, adjusted);

    _statuses[meal.id] = !ate
        ? MealStatus.skipped
        : partial
            ? MealStatus.partial
            : MealStatus.ate;

    if (!ate) _adjusted.remove(meal.id);
  }

  bool _isReduced(PlanMeal meal, List<MealItem> adjusted) {
    if (adjusted.length != meal.items.length) return true;
    for (var index = 0; index < adjusted.length; index++) {
      if (adjusted[index].qty != meal.items[index].qty) return true;
    }
    return false;
  }

  Future<void> _save(List<PlanMeal> meals) async {
    final repository = ref.read(checkinRepositoryProvider);
    if (repository == null) return;

    setState(() => _saving = true);

    final logged = <LoggedMeal>[];
    for (final meal in meals) {
      final status = _statuses[meal.id] ?? MealStatus.skipped;
      logged.add(
        LoggedMeal(
          mealId: meal.id,
          slot: meal.slot,
          label: meal.label,
          status: status,
          items: status == MealStatus.skipped
              ? const []
              : (_adjusted[meal.id] ?? meal.items),
        ),
      );
    }

    final log = DayLog(
      date: dayId(DateTime.now()),
      meals: logged,
      habits: DayHabits(workout: _workout, waterGlasses: _waterGlasses),
      checkedInAt: DateTime.now(),
    );

    try {
      await repository.saveDay(log);
      if (mounted) context.go(Routes.today);
    } catch (_) {
      // Firestore queues the write offline, so this is rare — but say so.
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally — it will sync shortly.')),
        );
        context.go(Routes.today);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealsAsync = ref.watch(planMealsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check in'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(Routes.today),
        ),
      ),
      body: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _CheckinMessage(
          icon: Icons.cloud_off,
          title: 'Could not load your plan',
          body: 'Check your connection and try again.',
        ),
        data: (meals) {
          if (meals.isEmpty) {
            return const _CheckinMessage(
              icon: Icons.restaurant_menu,
              title: 'No meals in your plan yet',
              body: 'Add your usual meals in My Plan, then check in here.',
            );
          }
          if (_finished) {
            return _summary(meals);
          }
          return _deck(meals);
        },
      ),
    );
  }

  Widget _deck(List<PlanMeal> meals) {
    // Meals first, then the habit cards.
    final cards = <Widget>[
      for (final meal in meals) _mealCard(meal),
      _habitCard(
        question: 'Did you train today?',
        yes: 'Yes, I trained',
        no: 'Rest day',
        onAnswer: (value) => _workout = value,
      ),
      _waterCard(),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Swipe right for yes, left for no',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: CardSwiper(
            controller: _controller,
            cardsCount: cards.length,
            numberOfCardsDisplayed: cards.length > 1 ? 2 : 1,
            isLoop: false,
            allowedSwipeDirection: const AllowedSwipeDirection.symmetric(
              horizontal: true,
            ),
            padding: const EdgeInsets.all(20),
            onSwipe: (previous, current, direction) {
              final ate = direction == CardSwiperDirection.right;
              if (previous < meals.length) {
                _answerMeal(meals[previous], ate: ate);
              } else if (previous == meals.length) {
                _workout = ate;
              }
              if (current == null) setState(() => _finished = true);
              return true;
            },
            cardBuilder: (context, index, _, __) => cards[index],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _controller.swipe(CardSwiperDirection.left),
                    icon: const Icon(Icons.close),
                    label: const Text('No'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _controller.swipe(CardSwiperDirection.right),
                    icon: const Icon(Icons.check),
                    label: const Text('Yes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mealCard(PlanMeal meal) {
    final items = _adjusted[meal.id] ?? meal.items;
    final kcal = items.fold<double>(0, (sum, item) => sum + item.kcal);
    final protein = items.fold<double>(0, (sum, item) => sum + item.proteinG);

    return _SwipeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal.slot.label.toUpperCase(),
            style: TextStyle(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            meal.summary,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Did you have this?',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          // The "only 3 eggs" case: adjust without leaving the card.
          for (var index = 0; index < items.length; index++)
            _StepperRow(
              item: items[index],
              onChanged: (qty) => setState(() {
                final next = [...items];
                next[index] = next[index].withQty(qty);
                _adjusted[meal.id] = next;
              }),
            ),
          const SizedBox(height: 12),
          Text(
            '${kcal.round()} kcal · ${protein.round()}g protein',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _habitCard({
    required String question,
    required String yes,
    required String no,
    required ValueChanged<bool> onAnswer,
  }) =>
      _SwipeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              question,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              'Swipe right for "$yes", left for "$no".',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  Widget _waterCard() => _SwipeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'How much water today?',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _waterGlasses > 0
                      ? () => setState(() => _waterGlasses--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    '$_waterGlasses glasses',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _waterGlasses < 20
                      ? () => setState(() => _waterGlasses++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Swipe either way when you are done.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  /// The summary card at the end of the deck.
  Widget _summary(List<PlanMeal> meals) {
    final eaten = _statuses.values
        .where((status) => status != MealStatus.skipped)
        .length;

    var kcal = 0.0;
    var protein = 0.0;
    for (final meal in meals) {
      if ((_statuses[meal.id] ?? MealStatus.skipped) == MealStatus.skipped) {
        continue;
      }
      final items = _adjusted[meal.id] ?? meal.items;
      kcal += items.fold<double>(0, (sum, item) => sum + item.kcal);
      protein += items.fold<double>(0, (sum, item) => sum + item.proteinG);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(
            Icons.check_circle,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'That is today done',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            '$eaten of ${meals.length} meals · ${kcal.round()} kcal · '
            '${protein.round()}g protein',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Spacer(),
          FilledButton(
            onPressed: _saving ? null : () => _save(meals),
            child: Text(_saving ? 'Saving…' : 'Done'),
          ),
          TextButton(
            onPressed: _saving ? null : () => setState(() => _finished = false),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      );
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.item, required this.onChanged});

  final MealItem item;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = item.qty >= 10 ? 10.0 : 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(item.display)),
          IconButton(
            onPressed: item.qty > 0 ? () => onChanged(item.qty - step) : null,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Less ${item.name}',
          ),
          IconButton(
            onPressed: () => onChanged(item.qty + step),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'More ${item.name}',
          ),
        ],
      ),
    );
  }
}

class _CheckinMessage extends StatelessWidget {
  const _CheckinMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
}
