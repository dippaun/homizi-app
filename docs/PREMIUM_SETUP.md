# HOMIZI Premium (RevenueCat)

Premium is a digital extra: unlimited owner contacts, a boosted listing, priority matches, and a verified Premium badge. Rent, deposits, and maintenance are **not** part of it. They stay on the Razorpay demo gateway (`docs/PAYMENTS_SETUP.md`).

## Code map

| Piece | File |
| --- | --- |
| Interface the paywall uses | `lib/features/premium/premium_service.dart` |
| RevenueCat implementation (`purchases_flutter`) | `lib/features/premium/revenuecat_premium_service.dart` |
| Demo implementation (no key, no network) | `lib/features/premium/demo_premium_service.dart` |
| Provider that picks one | `lib/features/premium/premium_providers.dart` |
| Paywall screen (`/premium`) | `lib/features/premium/premium_screen.dart` |
| Entry in Profile | `profile_me_screen.dart`, key `profile-premium-entry` |
| Confirmation | the shared `DemoSuccessScreen` at `/demo/done` |

## Which service runs

| `REVENUECAT_PUBLIC_KEY` | Service |
| --- | --- |
| empty | demo, on device, nothing charged |
| `test_…` in a debug or profile build | RevenueCat Test Store sandbox |
| `test_…` in a release build | demo (the RevenueCat SDK refuses a Test Store key in release on purpose) |
| `rcb_sb_…` | RevenueCat Web Billing sandbox |
| `rcb_…`, `appl_…`, `goog_…` | RevenueCat live. Do not use until the owner approves going live |

A secret key (`sk_…`) is refused by `AppConfig.parse`. The key is a `--dart-define`, never committed. Do not add it to `config/staging.json`.

```
flutter build web --profile --dart-define-from-file=config/staging.json \
  --dart-define=REVENUECAT_PUBLIC_KEY=<public key>
```

## RevenueCat objects (project `HOMIZI`)

- Test Store app `Test Store`
- Entitlement `premium` (HOMIZI Premium)
- Products `homizi_premium_monthly` (P1M) and `homizi_premium_annual` (P1Y)
- Offering `default` with packages `$rc_monthly` and `$rc_annual`

The Test Store prices in USD only (about $1.19 and $9.59, standing in for ₹99 and ₹799). The paywall prints ₹99/month and ₹799/year whenever RevenueCat does not report rupees.

## Going beyond the sandbox on web

Flutter web needs a **Web Billing** app in RevenueCat, and Web Billing needs a Stripe account connected through RevenueCat. Connecting Stripe is an OAuth step in the RevenueCat dashboard (Apps & providers, Web Billing, Connect Stripe). Use Stripe **test mode** first. Then create the same two products and the `default` offering for that app and compile its public `rcb_sb_…` key in. Web Billing prices can be in INR.

## Server mirror (proposed, not applied)

`docs/proposed/20261128120000_premium_entitlement.sql` adds an optional `premium_entitlements` table. It is **not** in `supabase/migrations` and has not been applied anywhere.
