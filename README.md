# Ottos frontend

Flutter monorepo (pub workspace + Melos) for Ottos. The backend lives in [jjhurtado/ottos](https://github.com/jjhurtado/ottos).

| Path | What it is |
| --- | --- |
| `packages/ottos_core` | Shared code: API client with token refresh, auth (Bloc), models, theme, widgets |
| `apps/ottos_ops` | Operations panel (Flutter Web) for admin and sales |
| `apps/ottos_courier` | Courier app (Android/iOS) |

The UI is in Spanish; code is in English. State management uses Bloc and routing uses go_router with permission guards.

## Documentation

The team documents (vision, architecture, API contract, data model, standards, screen map, roadmap, decisions as
ADRs) live in the backend repository [jjhurtado/ottos](https://github.com/jjhurtado/ottos) under `docs/`, as its
`docs/team/SETTINGS.md` says.

| Document | What it covers |
| --- | --- |
| [CLAUDE.md](CLAUDE.md) | Short index for agents |
| [STANDARDS.md](STANDARDS.md) | Link to the shared standards in `ottos/docs/STANDARDS.md` |
| [CHANGELOG.md](CHANGELOG.md) | Changes per version, for the people who use the apps |
| [roadmap.md](roadmap.md) | Pending work of the frontend |
| [docs/decisiones.md](docs/decisiones.md) | Decisions up to 2026-11-05, kept as history; new ones are ADRs in `ottos/docs/architecture/adr/` |
| `ottos/docs/ui/README.md` | The two official design canvases and their rules |
| `ottos/docs/team/tech/dart-flutter.md` | Commands, structure, tests and dependencies of this repository |
| Each package's README | [ottos_core](packages/ottos_core/README.md), [ottos_ops](apps/ottos_ops/README.md), [ottos_courier](apps/ottos_courier/README.md) |

## Environments

| Environment | API | Panel |
| --- | --- | --- |
| Local | `http://localhost:8080` (`10.0.2.2:8080` from the Android emulator) | `http://localhost:5050` |
| Staging | see `.env.staging.local` | panel-staging |
| Production | `https://api.remesadeotto.com` | `https://panel.remesadeotto.com` |

Staging deploys `develop` and production deploys `main`; Railway is configured by the infrastructure session, never
from here. The backend reads the app versions (`app_releases`) only once at startup: after inserting a row, restart
it.

## Security

- Never print secrets. The local admin password is read only with
  `grep -E '^OTTOS_ADMIN_PASSWORD=' ../ottos/.env`.
- Local test credentials live in `.env.local` and staging ones in `.env.staging.local`; both are git-ignored.
- Never type staging or production passwords into a browser or emulator: remote environments are tested through the
  API with scripts. Production has only the owner's admin and locks for 15 minutes after 5 failures, so no guessed
  attempts. Do not change the admin password.
- The Android signing key lives in `~/.ottos-release/`, outside the repository;
  `apps/ottos_courier/android/key.properties` is git-ignored.

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

### Android

The release key lives outside the repository, in `~/.ottos-release/` (`ottos-release.jks` and `key.properties`).
**Keep a copy somewhere safe**: without it, phones that have the app cannot install updates.
`apps/ottos_courier/android/key.properties` (git-ignored) points to it.

```sh
cd apps/ottos_courier
flutter build apk --release --split-per-abi --dart-define=OTTOS_API_URL=https://api.remesadeotto.com
```

`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` fits most phones (about 21 MB);
`app-armeabi-v7a-release.apk` is for older ones. Without `key.properties` a release build fails (REQ-023).

In-app updates (REQ-023): per-ABI APKs carry versionCode `1000 × ABI + build` (armeabi-v7a `1000 + N`, arm64
`2000 + N`), and Android refuses a lower one, so a universal APK (versionCode `N`) cannot update them. The app takes
its ABI from its versionCode and downloads `/descargas/ottos-<version>-<abi>.apk`: upload
`ottos-<version>-arm64-v8a.apk` and `ottos-<version>-armeabi-v7a.apk` (the split files renamed).

Transition: builds up to 14 have no in-app update; their «Actualizar» opens the browser at `ottos-<version>.apk`,
without a suffix. Also upload the arm64-v8a split under that plain name for them (one manual install); an armeabi-v7a
phone, if any, gets its APK by hand. The app checks before installing that the file is a newer build of
`com.remesadeotto.ottos` signed with the same key; otherwise it deletes it and shows the error.

For Google Play (decided 2026-10-13, not published yet) build an App Bundle instead and upload it to Play Console; the
key above is the upload key:

```sh
flutter build appbundle --release --dart-define=OTTOS_API_URL=https://api.remesadeotto.com
```

### After publishing a build

Send the backend agent the platform (`ANDROID`/`IOS`), the build number (the `+N` in `pubspec.yaml`, not the per-ABI
versionCode), the version name, whether it is mandatory and the notes. The backend publishes them with a migration;
that is what shows the "new version" notice or blocks older builds.

### iOS (TestFlight)

From a Mac, step by step: [docs/ios-en-mac.md](docs/ios-en-mac.md). Without a Mac: built on a GitHub Mac by the "iOS · TestFlight" workflow (`.github/workflows/ios-testflight.yml`), run by hand from
the Actions tab. It needs an Apple Developer account, the app created in App Store Connect with the identifier above,
and four repository secrets listed at the top of the workflow.

### Panel (web)

`apps/ottos_ops/Dockerfile`, built from the repository root; it serves the panel and forwards `/api` to
`OTTOS_BACKEND_URL`, and `/descargas/ottos-*.apk` to the bucket in `APK_BUCKET_UPSTREAM` (REQ-023).
