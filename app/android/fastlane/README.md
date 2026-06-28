# Android Firebase App Distribution pipeline

`fastlane beta` uploads a signed release APK to Firebase App Distribution — the
Android analogue of the iOS `fastlane beta` → TestFlight lane. It runs in CI
from `.github/workflows/android-firebase-distribution.yml` on a `v*` tag push or
a manual **Run workflow** dispatch — never on an ordinary push (that stays on
`ci.yml`).

## How it fits together

1. The workflow compiles the signed release APK (`flutter build apk --release
   --dart-define=REVENUECAT_API_KEY=…`). The Gradle release `signingConfig`
   reads the keystore from `ANDROID_KEYSTORE_PATH` + the password/alias env vars
   (a debug-keys fallback keeps local `flutter run --release` working with no
   secrets).
2. `fastlane beta` uploads that APK to Firebase App Distribution via the
   `firebase_app_distribution` plugin.
3. Auth uses a Google **service-account JSON** (Firebase App Distribution Admin
   role) — no interactive login, so it runs unattended.

## Required GitHub secrets

Everything is read from the environment; nothing secret is committed.

| Secret | What it is |
| --- | --- |
| `FIREBASE_ANDROID_APP_ID` | The Firebase Android App ID, e.g. `1:1234567890:android:abcdef` (Firebase console → Project settings → Your apps). |
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | A Google service-account JSON (Firebase App Distribution Admin), **base64-encoded** (`base64 -i service-account.json`). |
| `FIREBASE_DISTRIBUTION_GROUPS` | Comma-separated tester group aliases configured in Firebase (defaults to `internal-testers` if unset). |
| `ANDROID_KEYSTORE_BASE64` | The release keystore (`.jks`), **base64-encoded** (`base64 -i release.keystore`). |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password. |
| `ANDROID_KEY_ALIAS` | Key alias inside the keystore. |
| `ANDROID_KEY_PASSWORD` | Password for that key. |
| `REVENUECAT_API_KEY` | The **public** RevenueCat SDK key compiled into the build (not a secret like the server-only Claude key, but kept out of the repo). |

## One-time bootstrap (from a trusted machine, not CI)

```sh
# 1. Generate the release keystore (keep it safe — losing it blocks updates):
keytool -genkey -v -keystore release.keystore -keyalg RSA -keysize 2048 \
  -validity 10000 -alias gymbuddy

# 2. In the Firebase console, register the Android app (package
#    com.gymbuddy.gymbuddy) and create a tester group. Create a service account
#    with the "Firebase App Distribution Admin" role and download its JSON key.

# 3. base64-encode the keystore + service-account JSON and store all the values
#    above as GitHub Actions secrets.
```

For local signing, drop the same values into `app/android/key.properties`
(gitignored): `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.

## Run it locally

```sh
cd app
flutter build apk --release --dart-define=REVENUECAT_API_KEY=…
cd android
bundle install
FIREBASE_ANDROID_APP_ID=… FIREBASE_SERVICE_CREDENTIALS_FILE=… \
  bundle exec fastlane beta
```
