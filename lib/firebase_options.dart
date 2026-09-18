// Placeholder. `flutterfire configure` overwrites this file with your own
// project's values:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Demo mode never reads it — `main.dart` skips Firebase entirely when
// DEMO_MODE is set, which is how the app runs with no cloud account.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnimplementedError(
        'Run `flutterfire configure` to generate lib/firebase_options.dart, '
        'or run in demo mode with --dart-define=DEMO_MODE=true',
      );
}
