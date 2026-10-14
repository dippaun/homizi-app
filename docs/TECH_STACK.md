# Tech stack

Record of what this repository uses. Production hosting is not chosen beyond the local Supabase schema. See [DECISIONS.md](DECISIONS.md) and [plan/PLAN_DIFF.md](plan/PLAN_DIFF.md).

| Layer | Choice in this repo |
| --- | --- |
| Client | Flutter and Dart. Android is the first install target. The iOS project is kept. |
| UI | Material 3, `ColorScheme.fromSeed` with seed `#F75620`, white surfaces, Plus Jakarta Sans. |
| State and navigation | Riverpod and go_router. The shell stays on welcome or sign-in until a session is ready. |
| Local backend | Supabase Postgres, Auth, Storage, and row level security. Migrations live in `supabase/migrations/`. |
| Contact and matches | Postgres functions, not Edge Functions. |
| Languages | English and Hindi. `lib/l10n` and `lib/core/l10n/translate.dart`. |
| CI | Flutter 3.47.7 on Ubuntu: format, analyze, test, secret scan, dependency scan, debug APK, and `supabase test db`. |
| Lockfile floor | Dart `>=3.12.2 <4.0.0` and Flutter `>=3.44.0`, so Flutter 3.44.6 stable can resolve it. |
| Android SDK | `minSdk`, `compileSdk`, and `targetSdk` follow the Flutter defaults. Flutter 3.44.6 and 3.47.7 use API 36. |
| Package id | `in.homizi.app`. Android namespace `app.homizi`. |

Firebase App Distribution, Play Console, and a production Supabase project are not configured. `.github/workflows/distribute.yml` uploads a debug APK only when the Firebase secrets are present.
