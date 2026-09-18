# Nourish

Tell Nourish how you eat once, then keep it honest in 20 seconds a day.

Most food trackers ask people to weigh and log every ingredient, so most quit
within a week. But most people eat roughly the same things most days. Nourish
learns your usual meals once, then daily logging becomes a few swipes.

Flutter (Android and iOS) with a Firebase backend. Phase 1 targets a signed
APK a tester can install.

## Status

| Area | State |
| --- | --- |
| Domain models, targets calculator, streaks | Written, unit tested |
| `parseMeal` Cloud Function | Written, 45 tests passing |
| Firestore security rules | Written, not yet run against the emulator |
| App screens (sign-in, quiz, chat, Today, Plan, check-in, History, Profile) | Written, not yet compiled |
| Firebase project wiring | Not done — needs `flutterfire configure` |
| Android signing and APK | Not done |

Nothing Dart here has been compiled yet: it was written without a Flutter SDK
available. Expect to fix analyzer errors on the first `flutter run`.

## Getting it running

```bash
# 1. Toolchain
flutter doctor           # everything green before continuing

# 2. Firebase project
dart pub global activate flutterfire_cli
flutterfire configure    # writes lib/firebase_options.dart + google-services.json

# 3. Dependencies
flutter pub get
flutter analyze          # fix what this reports first
flutter test

# 4. Cloud Functions
cd functions && npm install && npm test
```

In the Firebase console you also need to:

- enable **Google** as a sign-in provider under Authentication
- create a **Firestore** database
- enable **App Check** (the callable functions require it)
- set the function secrets:

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set USDA_API_KEY   # optional, for gap-filling
firebase deploy --only functions,firestore:rules
```

## How it fits together

```
Flutter app ──► Firebase Auth (Google)
            ──► Cloud Firestore   (plans, check-ins; offline cache on)
            ──► Cloud Function    parseMeal ──► Gemini ──► USDA
            ──► Local notifications (8am / 8pm, no server)
```

The Gemini key lives in Secret Manager and is read only inside the function.
It is never compiled into the APK.

### The daily loop

1. **Onboarding** — a six-screen quiz, then a chat where you describe each meal
   in plain language ("six eggs and two bananas").
2. **parseMeal** turns that sentence into structured items. You confirm them on
   cards before anything is saved.
3. **My Plan** holds those meals, editable at any time.
4. **Two notifications a day** open the swipe check-in directly, cold start
   included.
5. **Check-in** is a card deck: right for yes, left for no, a stepper when you
   only had three of the six eggs.
6. **Today and History** show calories, protein and consistency.

## Layout

```
lib/
  core/            theme, router, shared enums and Firestore paths
  features/
    auth/          Google sign-in
    onboarding/    quiz, chat, profile, targets calculator
    plan/          meal models, parser client, My Plan
    checkin/       day log, swipe deck
    today/  history/  profile/  notifications/
  shared/widgets/  rings, choice tiles, confirm cards
functions/         parseMeal and deleteAccount
test/              Dart unit tests
legacy/web-prototype/   the earlier Flutter web demo (see below)
```

## Design decisions worth knowing

**Nutrition is stored per item, for the whole quantity.** Six eggs is 432 kcal,
not 72 with a multiplier applied later. Totalling a meal is a plain sum, and
scaling a partial portion is one multiplication.

**Calories are recomputed from macros when the model contradicts itself.** If
Gemini returns 36g protein and 72 kcal, the macros win — they are what the
rings and the protein target are built from.

**The parser asks rather than fails.** If it cannot read a sentence it returns
one clarifying question and whatever items it did understand, instead of an
error.

**One document per day.** `users/{uid}/days/2026-09-17` stores that day's meals
and its totals, so a month view is about 30 small reads and no maths on the
phone.

**A missed day is grey, never red.** Shaming people is how they quit.

## Privacy

Every document lives under `users/{uid}`, and the Firestore rules allow a user
to touch only their own. Delete account runs server-side, removing every
subcollection and the auth record. Nutrition figures are estimates, shown as
such, and are not medical advice.

`android/key.properties`, the keystore, `google-services.json` and
`lib/firebase_options.dart` are gitignored and must stay out of the repo.

## The earlier web prototype

`legacy/web-prototype/` holds the Flutter web demo this repo started as, kept
intact so the Vercel deploy keeps working — `vercel.json` still points at it.
It is a separate app: single-blob storage keyed by a browser cookie, no user
accounts. None of it carries into the mobile app, but it is there for demos.

## Next

- Run `flutter analyze` and fix what the first compile turns up
- Test the Firestore rules in the emulator
- Android signing config and a first APK to Firebase App Distribution
- Widget tests for the check-in deck
