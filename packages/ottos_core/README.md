# ottos_core · shared code

Everything the panel (`apps/ottos_ops`) and the app (`apps/ottos_courier`) both use. An app never imports from the
other; anything they share comes here. Layers and conventions are in [STANDARDS.md](../../STANDARDS.md#2-arquitectura-del-frontend).

## Layout (`lib/src/`)

| Path | What it is |
| --- | --- |
| `api/` | `ApiClient`: the only HTTP caller. Adds the token and refreshes it on 401. Sends `X-App-Platform`/`X-App-Build` on mobile and emits `updateRequired` on 426. Turns every error into an `ApiException` with the backend `code` |
| `config/` | `AppConfig.fromEnvironment` (`OTTOS_API_URL`, client WEB/MOBILE, `AppIdentity`) |
| `app/` | `OttosScope` (creates every repository once, read with `context.read`) and localization |
| `auth/` | `AuthBloc`, login page and cubit, remember-me, token storage, `Permissions` and `CurrentUser.can` |
| `models/` | Immutable models with null-tolerant `fromJson`. What goes to the API is an `XInput`/`NewX` with `toJson` |
| `remittances/`, `customers/`, `cash/`, `rates/`, `users/`, `reports/`, `audit/`, `sync/`, `app_version/` | One repository per backend area, one method per endpoint |
| `widgets/` | Dialogs and widgets both apps use: deliver/postpone/incident, assign, customer and beneficiary forms, cash operations, exchange, banners, status chips |
| `l10n/core_texts.dart` | Shared UI texts (Spanish) and the translation of backend error codes, statuses, roles and permissions |
| `theme/` | Colors and Material theme |
| `utils/` | Formatters, CSV, phones, auth redirect for go_router |

## Rules worth knowing

- **Permissions, never roles**: `user.can(Permissions.x)`. System roles and permissions are stored in English by the
  backend and shown in Spanish by their code.
- **Backend errors are translated by `code`** (`CoreTexts.errorCodes`). If a code has no translation, the
  backend's `detail` is shown. Add a translation whenever a new code reaches the UI.
- **Money is `double` for display only**; quotes and totals come from the backend.
- A dialog that both apps need (for example, the customer form, moved here on 2026-10-12 so sales can use it in the app)
  lives in `widgets/`. It saves itself and returns the result.

## Tests

```sh
flutter test --exclude-tags integration
```

`test/integration` runs against a live backend (tag `integration`). It is skipped unless `OTTOS_TEST_EMAIL` and
`OTTOS_TEST_PASSWORD` are set, and it writes data to that backend.
