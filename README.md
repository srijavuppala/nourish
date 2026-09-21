# Nourish

Tell Nourish how you eat once, then keep it honest in 20 seconds a day.

Most food trackers ask people to weigh and log every ingredient, so most quit
within a week. But most people eat roughly the same things most days. Nourish
learns your usual meals once, then daily logging becomes a few swipes.

Flutter (web, Android and iOS) with a Firebase backend. There is a demo mode
that runs in a browser with no cloud account, for showing the app before any
of it is set up.

## Run it right now, for free

No Firebase project, no API keys, no Android phone. Demo mode stores
everything in the browser and parses meals on-device:

```bash
flutter pub get
flutter run -d chrome --dart-define=DEMO_MODE=true
```

That is the build to screen-share. Sign-in is a button that just works, and
the meal parser understands the phrasings people actually type — "six eggs and
two bananas", "2 rotis with dal", "150g chicken breast". **Delete my account**
in Profile clears the demo data.

To hand someone a link instead, build it and upload the folder anywhere
static (Firebase Hosting, Vercel, GitHub Pages — all free tiers):

```bash
flutter build web --release --dart-define=DEMO_MODE=true
# serve build/web/
```

Demo mode is a compile-time flag. Leave it off and the same code talks to
Firebase.

## Status

| Area | State |
| --- | --- |
| Analyzer | Clean — `No issues found!` |
| Dart unit tests | 39 passing |
| Cloud Function tests | 45 passing |
| Demo mode on web | Verified in Chromium end to end: sign-in, quiz, chat parsing, check-in deck, save, History |
| Deploy config | Vercel and Firebase Hosting both build the demo app |
| Firestore security rules | 64 tests passing against the Firestore emulator |
| Firebase project wiring | Not done — needs `flutterfire configure` |
| Android signing and APK | Not done |

## Getting it running against Firebase

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
cd functions && npm install
npm test           # parser unit tests
npm run test:rules # security rules, against the Firestore emulator (needs Java)
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

## Deploying the demo

`vercel.json` and `firebase.json` both build the demo-mode web app, so either
host works with no extra setup:

```bash
# Vercel: connect the repo, or
npx vercel --prod

# Firebase Hosting
bash scripts/build-web-demo.sh
firebase deploy --only hosting
```

`scripts/build-web-demo.sh` fetches the pinned Flutter SDK if the build
machine has none, so CI needs nothing installed.

## Known gaps

- Typing a second meal before confirming the first silently replaces the
  pending card. Fine when you are correcting yourself, confusing otherwise.
- Notifications are a no-op on web. They are a phone feature, and the web
  build exists to be demoed.
- The on-device demo parser knows about 25 foods. Anything else asks a
  clarifying question. The real Gemini parser has no such limit.

## Next

- Widget tests for the chat and onboarding screens
- Android signing config and a first APK, once there is an Android tester
