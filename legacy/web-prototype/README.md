# Nourish
Flutter web nutrition prototype. Mobile-ready widgets with responsive desktop and phone layouts.

## Vercel presentation demo
`bash scripts/build-vercel.sh` builds the Flutter web demo with `DEMO_MODE=true`.
`vercel.json` defines the build and output directory; no API keys are needed.
The pinned Flutter SDK is installed if absent. Vercel serves the compiled app.

The demo uses synthetic records for Alex, dated relative to first opening. Each
visitor's edits are saved only in that browser, using a dedicated local storage key.
**Reset demo** clears that key and restores today's sample records. No private
diary is copied, and no Supabase or D1 requests are made in demo mode.
Photos stay in memory; recognition uses explicitly simulated sample ingredients.
Supabase integration remains prepared but not connected or verified live.

The presentation build also includes a five-step guided tour, responsive dashboard
shortcuts for the four main actions, and animated nutrition feedback. The tour moves
through the diary, meal planner, workouts and progress pages without editing data.

Suggested 3-minute presentation:
1. Dashboard: show calorie and macro totals, water tracking, and cuisine suggestions.
2. Food diary: add a sample meal and change its portion size.
3. Meal planner: log a planned dinner and show the grocery checklist.
4. Workouts: open today's walk, check off its sets, and complete the session.
5. Progress: show the sample history, then use Reset demo for the next audience.

The separate `scripts/build.sh` build retains the original Sites/D1 backend.

## Features
- Personal preferences, cuisines, editable daily targets.
- Meal diary: manual search, custom entries, portion editing, deletion, date navigation.
- Curated sample recommendations with vegetarian filtering and bookmarks.
- Photo selection and clearly labeled sample review flow. No live AI or food API.
- Private D1 persistence, keyed by an opaque HttpOnly browser session cookie. No app-level accounts or cross-device sync yet.

## Run and build
Install Flutter stable and Node 22+, then run flutter pub get and npm ci.
Set FLUTTER_BIN to your Flutter executable if it is not at the build environment default.
Run npm run build. It generates dist/client (Flutter) and dist/server/index.js (Cloudflare Worker).
Deploy D1 binding DB with migrations in drizzle/.
CI=true prevents Flutter's cloud metadata detection; analytics is disabled for build commands.

## Data and privacy
Nutrition records are illustrative estimates. Images are illustrative, not exact recipes.
Photos selected for the demo stay in device memory and are never uploaded.
Diary state is server-persisted for the current browser session. Clearing cookies loses access to that session.
No subscription, live AI, health integration, or app-store release is included.

## Later
Add authenticated Supabase/API integration for portable mobile accounts, verified food data,
a real server-side vision provider, dietary exclusion checks, native camera integration, and mobile release testing.

## Expanded prototype
Weekly meal plans and grocery checklists, workout creation and scheduling, editable
sets/reps/load, per-set completion, a rest timer, water tracking and weight history are implemented.
Supabase Auth and account-state persistence are integrated behind runtime configuration.
Supabase schema and RLS are prepared but require the user's project connection and live verification.
The currently configured D1 backend continues to support the private preview until then.

EatSight reference: https://github.com/LakshmanTurlapati/EatSight
Reviewed README and analysis services as a product/architecture reference. No source code or
nutrition dataset was copied. Flutter remains the frontend. Photo ingredient review uses
explicitly illustrative demo data; no live AI analysis is claimed.
