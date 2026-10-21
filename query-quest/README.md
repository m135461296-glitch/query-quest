# Query Quest

A bite-sized SQL puzzle game built with Flutter. Read a sample table, write a basic SQL query, and unlock the next tile on the map.

## Run and build

1. Install Flutter and the Android SDK.
2. Run `flutter pub get`.
3. Start locally with `flutter run`.
4. Build an installable APK with `flutter build apk --release` (output: `build/app/outputs/flutter-apk/app-release.apk`).

## Game features

- 100 levels with changing sample data and a Candy Crush-inspired level path.
- XP, player levels, combo streak rewards, coins, and ranks: Data Newbie, Query Knight, Join Wizard, Schema Sage, and SQL Overlord.
- Coin shop with Hint Tokens, Skip Tokens, Combo Shields, XP Surges, equipable HUD badges, and purchasable name cards.
- Earn a unique level badge when each puzzle is solved; skips never count as clears.
- Power-ups are saved: hints reveal progressive clues (up to three per level), skips unlock without awarding XP or a badge, shields preserve a streak while a wrong answer still costs one heart, and XP Surge doubles the next uncleared level's XP.
- Player profile with a gallery avatar, display name, level, rank, XP, and puzzle count.
- Progress, inventory, and profile details save locally. The avatar image is stored on the device.

## Supabase accounts and progress sync

Create a Supabase project, run `supabase/schema.sql` in its SQL editor, and enable Email provider in Supabase Authentication. Build with your project's URL and public publishable key (or legacy anon key):

`flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY`

The app opens with a Supabase email/password sign-in screen and supports account creation. Never put a user's password, Supabase service-role key, or any secret key in the app. The public publishable/anon key is designed for client apps; keep Row Level Security enabled and use the policies in `supabase/schema.sql`. To build an APK with account sign-in and cloud progress sync, add the same two `--dart-define` options to `flutter build apk --release`. Without them, the app shows a backend setup screen. Supabase stores progress and profile metadata, not the avatar image or SQL queries. Progress is associated with the authenticated user's ID; signing out returns to the sign-in page.

## SQL supported in practice mode

`SELECT` columns or `*`, aliases and qualified columns, `DISTINCT`, `WHERE` comparisons (`=`, `!=`, `>`, `<`, `>=`, `<=`, `LIKE`) joined with `AND`/`OR`, multi-column `ORDER BY`, and `LIMIT`. A trailing semicolon and SQL comments are allowed. Row order is only checked when the question requires sorting.

Example: `SELECT name FROM students WHERE grade = 'A'`

Queries run in a small local practice engine. They are not executed against a live SQL database; Supabase is used only for optional progress sync.
