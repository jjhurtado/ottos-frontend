# ottos_ops · operations panel

Flutter Web panel for **admin and sales**. It is the "night" tool: the place to review the day, manage customers,
cash, configuration, users and reports with more control than the app ([decisions](../../docs/decisiones.md#producto)).
Production: https://panel.remesadeotto.com · staging: panel-staging.

## Sections

Each section shows only with its permission (`lib/app/destinations.dart`), and each action only if the user has the
permission **and** the workflow allows it from the current status.

| Section | Path | Permission | What it does |
| --- | --- | --- | --- |
| Inicio | `features/home` | — | Open remittances by status, overdue, with incident, to review, exchanges to review |
| Remesas | `features/remittances` | `remittances:read` | List with filters, detail with history and cash movements, new remittance with quote, assign, deliver, postpone, incident, resolve review |
| Clientes | `features/customers` | `customers:read` | Customers and beneficiaries, CSV export/import with preview, loose beneficiaries import |
| Beneficiarios | `features/beneficiaries` | `customers:read` | Every beneficiary, with or without a customer: search, edit and create without a customer (`customers:write`) |
| Caja | `features/cash` | `cash:read` | Business cash, each courier's cash, fund/return, deposits, exchanges on behalf of a courier and to review |
| Configuración | `features/configuration` | `configuration:read` | Rates and commissions (deliveries and pickups separately), minimum amount, delivery days, exchange tolerance, calculator |
| Reportes | `features/reports` | `reports:read` | Monthly sales summary and its one-page A4 PDF (built in the browser) |
| Usuarios / Roles | `features/users`, `features/roles` | `users:read`, `roles:read` | Users, roles and permissions in Spanish; you can only grant permissions you hold |
| Auditoría | `features/audit` | `audit:read` | Who changed what and when |

Shared code (API, repositories, models, dialogs, login) is in [`ottos_core`](../../packages/ottos_core/README.md).

## Run locally

```sh
flutter run -d chrome --web-port 5050
```

`web_dev_config.yaml` proxies `/api` to `localhost:8080`, so the panel always calls its own origin, the same as in
production.

## Deploy

`Dockerfile` (built from the repository root because the panel needs `packages/ottos_core`) builds the web with the
exact Flutter version and serves it with Caddy (`Caddyfile`):

- `/api/*` is forwarded to `OTTOS_BACKEND_URL` (the backend's private address on Railway). It keeps the client
  IP headers, because the login limit works per IP. Same origin means no CORS and no per-environment API URL.
- The app shell is served with `no-cache` and the assets with one day of cache. Flutter web file names carry no hash,
  so this is what makes a deploy show up.
- Roboto is bundled and nothing is requested from Google. Google may be blocked from Cuba.

Railway and the domains are handled by the infrastructure agent, not from this repo.
