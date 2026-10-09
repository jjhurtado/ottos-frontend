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
