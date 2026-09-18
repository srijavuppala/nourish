import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo_mode.dart';
import '../../auth/data/auth_repository.dart';
import '../../demo/demo_seed.dart';
import '../../notifications/notification_service.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/models/targets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _service = NotificationService();

  Reminder _morning = defaultMorning;
  Reminder _evening = defaultEvening;
  bool _remindersOn = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _service.loadSettings();
    if (!mounted) return;
    setState(() {
      _morning = settings.morning;
      _evening = settings.evening;
      _remindersOn = settings.enabled;
      _loaded = true;
    });
  }

  Future<void> _applyReminders({required bool enabled}) async {
    if (!enabled) {
      await _service.cancelAll();
      if (mounted) setState(() => _remindersOn = false);
      return;
    }

    if (!await _service.requestPermissions()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow notifications in system settings first.'),
          ),
        );
      }
      return;
    }

    await _service.scheduleDaily(morning: _morning, evening: _evening);
    if (mounted) setState(() => _remindersOn = true);
  }

  Future<void> _pickTime({required bool morning}) async {
    final current = morning ? _morning : _evening;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;

    setState(() {
      final reminder = Reminder(picked.hour, picked.minute);
      if (morning) {
        _morning = reminder;
      } else {
        _evening = reminder;
      }
    });

    if (_remindersOn) await _applyReminders(enabled: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final targets = ref.watch(targetsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (user != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage:
                    user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
                child: user.photoUrl == null ? const Icon(Icons.person) : null,
              ),
              title: Text(user.displayName ?? 'Signed in'),
              subtitle: Text(user.email ?? ''),
            ),
          const SizedBox(height: 16),
          Text('Targets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (targets == null)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Finish onboarding to see your targets.'),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _targetRow('Calories', '${targets.calories} kcal'),
                    _targetRow('Protein', '${targets.proteinG}g'),
                    _targetRow('Carbs', '${targets.carbsG}g'),
                    _targetRow('Fat', '${targets.fatG}g'),
                    if (targets.explanation.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        targets.explanation,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _editTargets(targets),
                      child: const Text('Edit targets'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!_loaded)
            const LinearProgressIndicator(minHeight: 2)
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _remindersOn,
              onChanged: (value) => _applyReminders(enabled: value),
              title: const Text('Daily check-in reminders'),
              subtitle: const Text('Two a day, at times you choose.'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: _remindersOn,
              title: const Text('Morning'),
              trailing: Text(_morning.formatted),
              onTap: () => _pickTime(morning: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: _remindersOn,
              title: const Text('Evening'),
              trailing: Text(_evening.formatted),
              onTap: () => _pickTime(morning: false),
            ),
          ],
          const SizedBox(height: 24),
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
          // Demo builds only: put the sample data back the way it started,
          // so the next run-through begins from the same place.
          if (kDemoMode)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset demo'),
              subtitle: const Text('Restores the sample plan and history.'),
              onTap: _resetDemo,
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,),
            title: Text(
              'Delete my account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Removes every meal and check-in, permanently.'),
            onTap: _confirmDelete,
          ),
          const SizedBox(height: 24),
          Text(
            'Nutrition figures are estimates, not medical advice.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _targetRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Future<void> _editTargets(Targets targets) async {
    final calories = TextEditingController(text: '${targets.calories}');
    final protein = TextEditingController(text: '${targets.proteinG}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit targets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: calories,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: protein,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Protein (g)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final newCalories = int.tryParse(calories.text);
    final newProtein = int.tryParse(protein.text);
    if (newCalories == null || newProtein == null) return;
    if (newCalories < 800 || newCalories > 8000) return;
    if (newProtein < 20 || newProtein > 400) return;

    await ref.read(onboardingRepositoryProvider)?.saveTargets(
          targets.copyWith(
            calories: newCalories,
            proteinG: newProtein,
            // The stored reasoning described the old numbers.
            explanation: 'You set these yourself.',
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _resetDemo() async {
    await ref.read(authRepositoryProvider).deleteAccount();
    await seedDemoData();
    await ref.read(authRepositoryProvider).signIn();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo reset.')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Your meals, check-ins and history are deleted permanently. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.cancelAll();
      await ref.read(authRepositoryProvider).deleteAccount();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete just now.')),
        );
      }
    }
  }
}
