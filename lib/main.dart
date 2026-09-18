import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'features/notifications/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Must run before the router is built: it sets launchPayload, which decides
  // whether a cold start opens Today or the check-in.
  await NotificationService().initialize();

  runApp(const ProviderScope(child: NourishApp()));
}

class NourishApp extends ConsumerStatefulWidget {
  const NourishApp({super.key});

  @override
  ConsumerState<NourishApp> createState() => _NourishAppState();
}

class _NourishAppState extends ConsumerState<NourishApp> {
  @override
  void initState() {
    super.initState();
    // A tap while the app is already running.
    NotificationService.tapped.addListener(_onNotificationTapped);
  }

  @override
  void dispose() {
    NotificationService.tapped.removeListener(_onNotificationTapped);
    super.dispose();
  }

  void _onNotificationTapped() {
    if (NotificationService.tapped.value != checkinPayload) return;
    NotificationService.tapped.value = null;
    ref.read(routerProvider).go(Routes.checkin);
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Nourish',
        debugShowCheckedModeBanner: false,
        theme: NourishTheme.light(),
        darkTheme: NourishTheme.dark(),
        routerConfig: ref.watch(routerProvider),
      );
}
