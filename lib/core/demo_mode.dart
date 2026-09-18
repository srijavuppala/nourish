/// Demo mode runs the whole app with no Firebase project and no API keys:
/// storage is the browser's own, and meal parsing is done on-device.
///
/// Build it with:
///   flutter run -d chrome --dart-define=DEMO_MODE=true
///
/// It exists so the app can be shown on a laptop, for free, before any cloud
/// account is set up. Real builds leave the flag off and use Firebase.
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');
