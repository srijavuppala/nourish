# Supabase connection
Status: prepared in source; not provisioned or connected until a project is authorized.

1. Select the user's Supabase project through the Supabase connection.
2. Apply migrations/202609170001_nourish.sql once; verify RLS and grants with two separate test users.
3. Enable email sign-in. Add the exact Nourish production URL to Site URL and redirect allowlist.
4. Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in Sites runtime environment.
   Only the publishable/anon key is returned by /api/config. Never use a service-role or secret key there.
5. Reload the app, sign in, then verify save/reload and cross-account isolation before calling connection complete.
6. Existing D1 diary remains unchanged; a new Supabase account starts empty. Plan an explicit import before transferring old data.
7. For future mobile builds, configure the approved native auth callback and provide the project config through build-time options.
8. Live photo AI remains separately gated by its provider key and function deployment. Never label a sample response as real analysis.

The app uses Supabase Auth plus one account-owned JSON state record for diary, planner, workouts, hydration and progress.
meal_analyses is prepared for future structured ingredient-analysis history.
