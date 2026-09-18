import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/router.dart';
import '../../../shared/widgets/choice_tile.dart';
import '../data/onboarding_repository.dart';
import '../data/targets_calculator.dart';
import '../models/profile.dart';

/// Six screens, one question each. Never a wall of fields.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  static const _stepCount = 6;

  final _controller = PageController();
  int _step = 0;
  bool _saving = false;

  Profile _profile = const Profile();
  final _avoidsController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _avoidsController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == _stepCount - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _controller.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _controller.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    final repository = ref.read(onboardingRepositoryProvider);
    if (repository == null) return;

    setState(() => _saving = true);

    final avoids = _avoidsController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final profile = _profile.copyWith(avoids: avoids);

    try {
      await repository.saveProfile(profile);
      // Targets are derived here so the chat screen can show them straight away.
      await repository.saveTargets(TargetsCalculator.fromProfile(profile));
      if (mounted) context.go(Routes.chat);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save that. Try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_stepCount, (index) {
            final done = index <= _step;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: done ? 20 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ),
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _goalStep(),
          _bodyStep(),
          _activityStep(),
          _dietStep(),
          _mealCountStep(),
          _timingStep(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: FilledButton(
          onPressed: _saving ? null : _next,
          child: Text(
            _saving
                ? 'Saving…'
                : _step == _stepCount - 1
                    ? 'Build my plan'
                    : 'Continue',
          ),
        ),
      ),
    );
  }

  Widget _question(String title, String subtitle, List<Widget> children) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      );

  Widget _goalStep() => _question(
        'What are you here for?',
        'This sets your calorie and protein targets.',
        [
          for (final goal in Goal.values)
            ChoiceTile(
              label: goal.label,
              selected: _profile.goal == goal,
              onTap: () => setState(() => _profile = _profile.copyWith(goal: goal)),
            ),
        ],
      );

  Widget _bodyStep() => _question(
        'A few basics',
        'We need these to work out how much you burn in a day.',
        [
          Row(
            children: [
              for (final sex in Sex.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceTile(
                      label: sex.label,
                      selected: _profile.sex == sex,
                      onTap: () =>
                          setState(() => _profile = _profile.copyWith(sex: sex)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _numberField(
            label: 'Age',
            suffix: 'years',
            value: _profile.age.toDouble(),
            min: 13,
            max: 100,
            onChanged: (value) =>
                setState(() => _profile = _profile.copyWith(age: value.round())),
          ),
          _numberField(
            label: 'Height',
            suffix: 'cm',
            value: _profile.heightCm,
            min: 120,
            max: 230,
            onChanged: (value) =>
                setState(() => _profile = _profile.copyWith(heightCm: value)),
          ),
          _numberField(
            label: 'Weight',
            suffix: 'kg',
            value: _profile.weightKg,
            min: 30,
            max: 250,
            onChanged: (value) =>
                setState(() => _profile = _profile.copyWith(weightKg: value)),
          ),
        ],
      );

  Widget _activityStep() => _question(
        'How active are you?',
        'Outside of deliberate exercise as well as in it.',
        [
          for (final level in ActivityLevel.values)
            ChoiceTile(
              label: level.label,
              detail: level.detail,
              selected: _profile.activityLevel == level,
              onTap: () => setState(
                () => _profile = _profile.copyWith(activityLevel: level),
              ),
            ),
        ],
      );

  Widget _dietStep() => _question(
        'How do you eat?',
        'We will never suggest something you avoid.',
        [
          for (final diet in DietType.values)
            ChoiceTile(
              label: diet.label,
              selected: _profile.dietType == diet,
              onTap: () => setState(
                () => _profile = _profile.copyWith(dietType: diet),
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _avoidsController,
            decoration: const InputDecoration(
              labelText: 'Anything you avoid?',
              hintText: 'peanuts, dairy, shellfish',
              helperText: 'Separate with commas. Leave blank if nothing.',
            ),
          ),
        ],
      );

  Widget _mealCountStep() => _question(
        'How many times a day do you eat?',
        'Including snacks you have most days.',
        [
          for (var count = 2; count <= 6; count++)
            ChoiceTile(
              label: '$count a day',
              selected: _profile.mealsPerDay == count,
              onTap: () => setState(
                () => _profile = _profile.copyWith(mealsPerDay: count),
              ),
            ),
        ],
      );

  Widget _timingStep() => _question(
        'When does your day run?',
        'We use these to suggest your two reminder times.',
        [
          _timeField(
            label: 'I usually train at',
            value: _profile.gymTime,
            onChanged: (value) =>
                setState(() => _profile = _profile.copyWith(gymTime: value)),
          ),
          const SizedBox(height: 12),
          _timeField(
            label: 'I usually finish eating by',
            value: _profile.mealTimes.isEmpty ? null : _profile.mealTimes.last,
            onChanged: (value) => setState(
              () => _profile = _profile.copyWith(mealTimes: [value]),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Both are optional — you can change your reminders later.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );

  Widget _numberField({
    required String label,
    required String suffix,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton.filledTonal(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 92,
              child: Text(
                '${value.round()} $suffix',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton.filledTonal(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      );

  Widget _timeField({
    required String label,
    required String? value,
    required ValueChanged<String> onChanged,
  }) =>
      OutlinedButton(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 8, minute: 0),
          );
          if (picked == null) return;
          onChanged(
            '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}',
          );
        },
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value ?? 'Set',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}
