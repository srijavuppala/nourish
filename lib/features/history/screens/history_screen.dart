import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/models/day_log.dart';
import '../../onboarding/data/onboarding_repository.dart';

/// A month calendar of coloured dots, and a sheet with the detail of any day.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(recentDaysProvider).valueOrNull ?? const [];
    final targets = ref.watch(targetsProvider).valueOrNull;
    final byDate = {for (final log in logs) log.date: log};

    final monthLogs = logs.where((log) {
      final date = DateTime.tryParse(log.date);
      return date != null &&
          date.year == _month.year &&
          date.month == _month.month;
    }).toList();

    final checkedIn = monthLogs.where((log) => log.checkedIn).length;
    final avgKcal = monthLogs.isEmpty
        ? 0
        : monthLogs.fold<double>(0, (sum, log) => sum + log.kcal) /
            monthLogs.length;
    final avgProtein = monthLogs.isEmpty
        ? 0
        : monthLogs.fold<double>(0, (sum, log) => sum + log.proteinG) /
            monthLogs.length;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
                onPressed: _canGoForward
                    ? () => setState(
                          () => _month = DateTime(_month.year, _month.month + 1),
                        )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CalendarGrid(
            month: _month,
            byDate: byDate,
            targetKcal: targets?.calories ?? 2000,
            onTapDay: (log, date) => _showDay(context, log, date),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This month',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _statRow('Days checked in', '$checkedIn'),
                  _statRow('Average calories', '${avgKcal.round()} kcal'),
                  _statRow('Average protein', '${avgProtein.round()}g'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canGoForward {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  void _showDay(BuildContext context, DayLog? log, DateTime date) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMMEEEEd().format(date),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (log == null || !log.checkedIn)
              Text(
                'No check-in for this day.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                '${log.kcal.round()} kcal · ${log.proteinG.round()}g protein',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              for (final meal in log.meals)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    switch (meal.status) {
                      MealStatus.ate => Icons.check_circle,
                      MealStatus.partial => Icons.adjust,
                      MealStatus.skipped => Icons.remove_circle_outline,
                    },
                    color: meal.status == MealStatus.skipped
                        ? NourishTheme.missedColor(context)
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(meal.slot.label),
                  subtitle: Text(
                    meal.items.isEmpty
                        ? 'Skipped'
                        : meal.items.map((item) => item.display).join(', '),
                  ),
                  trailing: Text('${meal.kcal.round()} kcal'),
                ),
              if (log.habits.workout || log.habits.waterGlasses > 0) ...[
                const Divider(),
                Text(
                  [
                    if (log.habits.workout) 'Trained',
                    if (log.habits.waterGlasses > 0)
                      '${log.habits.waterGlasses} glasses of water',
                  ].join(' · '),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.byDate,
    required this.targetKcal,
    required this.onTapDay,
  });

  final DateTime month;
  final Map<String, DayLog> byDate;
  final int targetKcal;
  final void Function(DayLog? log, DateTime date) onTapDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is 1 = Monday, and the grid starts on Monday.
    final leadingBlanks = DateTime(month.year, month.month).weekday - 1;
    final today = dayId(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();

            final day = index - leadingBlanks + 1;
            final date = DateTime(month.year, month.month, day);
            final id = dayId(date);
            final log = byDate[id];
            final checkedIn = log?.checkedIn ?? false;

            // On plan is within 15% of the calorie target.
            final onPlan = checkedIn &&
                targetKcal > 0 &&
                (log!.kcal - targetKcal).abs() / targetKcal <= 0.15;

            return Semantics(
              label: '$day ${checkedIn ? 'checked in' : 'not checked in'}',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTapDay(log, date),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: checkedIn
                        ? (onPlan
                            ? scheme.primaryContainer
                            : scheme.secondaryContainer)
                        // Grey, never red — a missed day is neutral.
                        : scheme.surfaceContainerHighest,
                    border: id == today
                        ? Border.all(color: scheme.primary, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontWeight:
                          checkedIn ? FontWeight.w600 : FontWeight.w400,
                      color: checkedIn
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
