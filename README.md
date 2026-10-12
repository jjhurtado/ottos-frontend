# Ottos frontend

Flutter monorepo (pub workspace + Melos) for Ottos. The backend lives in [jjhurtado/ottos](https://github.com/jjhurtado/ottos).

| Path | What it is |
| --- | --- |
| `packages/ottos_core` | Shared code: API client with token refresh, auth (Bloc), models, theme, widgets |
| `apps/ottos_ops` | Operations panel (Flutter Web) for admin and sales |
| `apps/ottos_courier` | Courier app (Android/iOS) |

The UI is in Spanish; code is in English. State management uses Bloc and routing uses go_router with permission guards.

## Setup

Requires Flutter with Dart `^3.13.5`.

```sh
flutter pub get          # resolves the whole workspace
dart run melos analyze   # flutter analyze in every package
```

## Run against the local backend

Start the backend first (`docker compose up -d postgres` and `./gradlew bootRun --args="--spring.profiles.active=dev"` in the backend repo). It listens on `localhost:8080`.

```sh
dart run melos ops       # operations panel on http://localhost:5050
dart run melos courier   # courier app on a device or emulator
```

On web, the dev server proxies `/api` to the backend (see `apps/ottos_ops/web_dev_config.yaml`). To point at another backend, pass `--dart-define=OTTOS_API_URL=https://host` (the origin, without `/api/v1`).

## Release the mobile app (Ottos)

Identifier `com.remesadeotto.ottos` on Android and iOS; production backend `https://api.remesadeotto.com`.

### Android (APK)

The release key lives outside the repository, in `~/.ottos-release/` (`ottos-release.jks` and `key.properties`).
**Keep a copy somewhere safe**: without it, phones that have the app cannot install updates.
`apps/ottos_courier/android/key.properties` (git-ignored) points to it.

```sh
cd apps/ottos_courier
flutter build apk --release --split-per-abi --dart-define=OTTOS_API_URL=https://api.remesadeotto.com
```

`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` fits most phones (about 21 MB);
`app-armeabi-v7a-release.apk` is for older ones.

### iOS (TestFlight)

From a Mac, step by step: [docs/ios-en-mac.md](docs/ios-en-mac.md). Without a Mac: built on a GitHub Mac by the "iOS · TestFlight" workflow (`.github/workflows/ios-testflight.yml`), run by hand from
the Actions tab. It needs an Apple Developer account, the app created in App Store Connect with the identifier above,
and four repository secrets listed at the top of the workflow.

### Panel (web)

`apps/ottos_ops/Dockerfile`, built from the repository root; it serves the panel and forwards `/api` to
`OTTOS_BACKEND_URL`.
