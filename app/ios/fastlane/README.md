# iOS TestFlight pipeline

`fastlane beta` builds a signed release IPA and ships it to TestFlight. It runs
in CI from `.github/workflows/ios-testflight.yml` on a `v*` tag push or a manual
**Run workflow** dispatch — never on an ordinary push (that stays on `ci.yml`).

## How it fits together

1. The workflow compiles the Flutter/Dart side (`flutter build ios --release
   --no-codesign --dart-define=REVENUECAT_API_KEY=…`), which regenerates
   `ios/Flutter/Generated.xcconfig`.
2. `fastlane beta` fetches signing material read-only via `match`, archives the
   `Runner` workspace with `build_app`, and uploads with `upload_to_testflight`.
3. Auth uses an **App Store Connect API key** (a `.p8`) — no Apple ID or 2FA, so
   it runs unattended.

## Required GitHub secrets

Everything is read from the environment; nothing secret is committed.

| Secret | What it is |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_ID` | The API key's Key ID (App Store Connect → Users and Access → Integrations → App Store Connect API). |
| `APP_STORE_CONNECT_API_ISSUER_ID` | The Issuer ID from the same page. |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | The `.p8` file contents, **base64-encoded** (`base64 -i AuthKey_XXX.p8`). |
| `APP_STORE_CONNECT_TEAM_ID` | App Store Connect team id (only if the account has multiple teams). |
| `DEVELOPER_PORTAL_TEAM_ID` | Apple Developer Portal team id that owns the certificates. |
| `MATCH_GIT_URL` | Private git repo holding the encrypted certs + profiles. |
| `MATCH_PASSWORD` | Passphrase that decrypts the match repo. |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64 `user:token` for cloning the match repo over HTTPS in CI. |
| `REVENUECAT_API_KEY` | The **public** RevenueCat SDK key compiled into the build (not a secret like the server-only Claude key, but kept out of the repo). |

## One-time bootstrap (from a trusted machine, not CI)

```sh
cd app/ios
bundle install
# Create / store the App Store distribution cert + provisioning profile.
bundle exec fastlane match appstore
```

After that, CI fetches them read-only on every run.

## Run it locally

```sh
cd app/ios
bundle install
flutter build ios --release --no-codesign --dart-define=REVENUECAT_API_KEY=…
bundle exec fastlane beta
```
