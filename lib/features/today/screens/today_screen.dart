import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/nutrient_ring.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/models/day_log.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../plan/data/plan_repository.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(targetsProvider).valueOrNull;
    final today = ref.watch(todayLogProvider).valueOrNull;
    final meals = ref.watch(planMealsProvider).valueOrNull ?? const [];
    final recent = ref.watch(recentDaysProvider).valueOrNull ?? const [];

    final streak = currentStreak(recent);
    final loggedIds = {
      for (final meal in today?.meals ?? const [])
        if (meal.status != MealStatus.skipped) meal.mealId,
    };
    final pending = meals.where((meal) => !loggedIds.contains(meal.id)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          if (streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.local_fire_department, size: 18),
                label: Text('$streak day${streak == 1 ? '' : 's'}'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  NutrientRing(
                    label: 'Calories',
                    value: today?.kcal ?? 0,
                    target: targets?.calories ?? 2000,
                    unit: 'kcal',
                    color: NourishTheme.calorieColor,
                  ),
                  NutrientRing(
                    label: 'Protein',
                    value: today?.proteinG ?? 0,
                    target: targets?.proteinG ?? 120,
                    unit: 'g',
                    color: NourishTheme.proteinColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (pending > 0)
            FilledButton.icon(
              onPressed: () => context.go(Routes.checkin),
              icon: const Icon(Icons.swipe),
              label: Text(
                today?.checkedIn ?? false
                    ? 'Update today'
                    : 'Check in · $pending meal${pending == 1 ? '' : 's'} left',
              ),
            )
          else if (meals.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your plan is empty',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add the meals you normally eat, and your daily check-in '
                      'builds itself from them.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go(Routes.plan),
                      child: const Text('Add a meal'),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('All checked in for today'),
                subtitle: const Text('Come back tomorrow.'),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            "Today's meals",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (meals.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Nothing planned yet.'),
            )
          else
            for (final meal in meals)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  loggedIds.contains(meal.id)
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: loggedIds.contains(meal.id)
                      ? Theme.of(context).colorScheme.primary
                      : NourishTheme.missedColor(context),
                ),
                title: Text(meal.slot.label),
                subtitle: Text(
                  meal.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('${meal.kcal.round()} kcal'),
              ),
        ],
      ),
    );
  }
}
