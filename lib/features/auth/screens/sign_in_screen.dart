import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo_mode.dart';
import '../../demo/demo_seed.dart';
import '../data/auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn({bool withSampleData = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Seed before signing in, so the first frame after the redirect already
      // has the sample plan and history.
      if (withSampleData) await seedDemoData();
      await ref.read(authRepositoryProvider).signIn();
      // On success the router redirects; no navigation needed here.
    } catch (_) {
      if (mounted) {
        setState(() => _error = "That didn't work. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.eco_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Nourish',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tell us how you eat once.\nThen keep it honest in 20 seconds a day.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 3),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(_busy ? 'Signing in…' : 'Continue with Google'),
              ),
              // Demo builds offer a second path: skip onboarding and land on
              // a dashboard that already has a fortnight of history.
              if (kDemoMode) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : () => _signIn(withSampleData: true),
                  child: const Text('Explore with sample data'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Your meals stay private. Delete everything whenever you want.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
