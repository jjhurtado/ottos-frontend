# ottos_courier · the Ottos mobile app

Android/iOS app, published as **Ottos** (`com.remesadeotto.ottos`). Despite the package name it is not only for
couriers: during the day **couriers and sales** both work with it, and what each one sees depends on their
permissions, never on their role ([decisions](../../docs/decisiones.md#producto)).

| User | What they do in the app |
| --- | --- |
| Courier (`remittances:read-assigned`, `remittances:deliver`, `cash:read-own`) | Their remittances, deliver (with or without PIN) or pick up, incidents, postpone, their own cash and currency exchange. **Works offline.** |
| Sales (`remittances:read`, `remittances:create`, `remittances:assign`, `cash:write`, `customers:write`) | Every open remittance, new remittance (creating sender/beneficiary on the spot), assign to a courier, fund couriers and take returns. **Online only.** |

## Layout

| Path | What it is |
| --- | --- |
| `lib/main.dart` | Opens the offline store, reads the app identity (platform + build) and starts `CourierApp` |
| `lib/app/` | App widget, router (go_router + permission guards), `CourierTexts`, biometrics |
| `lib/shell/` | Bottom navigation (Remesas, Caja, and Reportes and Estadísticas for sales with `reports:read`) |
| `lib/features/reports/` | Sales: the month's remittances and the statistics (shared views from core); «Exportar» shares the PDF or CSV with `share_plus` |
| `lib/features/assigned/` | Remittance list: the courier's own or, for sales, every open one (last 100) |
| `lib/features/remittance/` | Detail: deliver, pick up, PIN, incident, postpone, assign, call/WhatsApp |
| `lib/features/new_remittance/` | Sales registers a remittance with its quote (shares `NewRemittanceCubit` with the panel) |
| `lib/features/cash/` | Own cash and exchange (courier) or couriers' cash with fund/return (sales) |
| `lib/offline/` | SQLite store, `RemittanceSource` (online/offline), `SyncCubit` and the sync bar |
| `lib/notifications/` | Local notifications: new assignment (courier) and completed remittances (sales) |
| `lib/app_update/` | Version check, closable notice and the blocking "Actualiza para continuar" screen |

Everything shared with the panel (API client, repositories, models, dialogs, login) is in
[`ottos_core`](../../packages/ottos_core/README.md).

## How it works, and why

- **Offline-first** (contract `ottos/docs/contracts/offline-sync.md`). The courier's remittances, cash and the
  workflow are cached in SQLite. Actions go to a queue with a UUID and `occurredAt`, and `POST /sync/actions` sends
  them in batches when the network is back. With network and an empty queue, actions go straight to the API with
  `strictPin`. The app syncs on start, on network back, on resume, on pull-to-refresh and by hand. The session
  (`client: MOBILE`, 14 h) survives without network. Why: there are whole days without internet in Cuba.
- **Local notifications, no Firebase**. The app polls while open (every 2 min, on resume, on network back). Why: Google
  services may be blocked from Cuba. Trade-off: no notices while the app is closed.
- **Version gate** (contract `ottos/docs/contracts/app-version.md`). Every request carries `X-App-Platform` and
  `X-App-Build`. The app checks `GET /app/version` on start and on resume and caches the answer. Below the minimum
  build, or on a 426 `APP_UPDATE_REQUIRED`, it flushes the offline queue and shows a screen that cannot be closed.
  «Actualizar» opens the backend's `downloadUrl`, or the Play Store page / TestFlight app when there is none.
  The build is the `pubspec.yaml` `+N`. Per-ABI APKs report `abi*1000 + N`, so `main.dart` keeps the remainder of 1000.
- **Contacts through the system picker** (`flutter_native_contact_picker`, `lib/app/phone_contacts.dart`). New
  senders and beneficiaries can take name and phone from a contact. The system picker hands back only the chosen
  contact, so the app needs no contacts permission. Core's form dialogs take it as an optional `ContactPicker`.
- **Biometric login**. After a password login the app offers the fingerprint, and the credentials are kept in the
  Keystore/Keychain. A password change forgets them.

## Run

```sh
flutter run                                                     # local backend (10.0.2.2:8080 on the emulator)
flutter run --dart-define=OTTOS_API_URL=https://host           # another backend
```

Local test users are in the git-ignored `.env.local` at the repository root. Never type staging or production
passwords into the emulator; test remote environments through the API.

## Release

The version is in `pubspec.yaml` (`1.0.0-rc.N+build`, same version as the other packages) and is bumped in the
`release/` branch. Build commands and signing are in the [root README](../../README.md#release-the-mobile-app-ottos).
On iOS, build with `--build-name` set to the version without the pre-release tag (`1.0.0`): iOS takes at most three
integers, and Flutter would turn `1.0.0-rc.3` into `1.0.0.3`, which App Store Connect rejects. Never pass
`--build-number`; the `+N` is what the version gate compares.
After publishing a build, send the backend agent: platform, build number, version name, whether it is mandatory and
notes. The backend publishes them with a migration, and that is what turns the notice or the block on.
