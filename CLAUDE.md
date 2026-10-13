# Ottos frontend · contexto para agentes

Ottos es un negocio de remesas hacia Cuba: ventas cobra fuera y un repartidor entrega (o recoge) el dinero en casa
del beneficiario. Este repo es el frontend en Flutter; el backend (Spring Boot) está en `../ottos` (GitHub
`jjhurtado/ottos`). El dueño del negocio es el usuario: habla en español y decide el producto.

## Dónde está cada cosa

| Documento | Para qué |
| --- | --- |
| [README.md](README.md) | Montar el entorno, ejecutar contra el backend local y publicar (APK/AAB, iOS, panel) |
| [STANDARDS.md](STANDARDS.md) | Reglas obligatorias: Git Flow, commits, changelog, arquitectura por capas, tests |
| [roadmap.md](roadmap.md) | Qué está hecho, qué falta, versión actual y preguntas abiertas |
| [CHANGELOG.md](CHANGELOG.md) | Cambios por versión, escritos para quien usa las apps |
| [docs/decisiones.md](docs/decisiones.md) | Decisiones tomadas y **por qué**; leerlo antes de cambiar algo que parezca raro |
| [packages/ottos_core/README.md](packages/ottos_core/README.md) | Código compartido: API, sesión, repositorios, diálogos |
| [apps/ottos_ops/README.md](apps/ottos_ops/README.md) | Panel web (admin y ventas, «de noche») y su despliegue con Caddy |
| [apps/ottos_courier/README.md](apps/ottos_courier/README.md) | App móvil «Ottos» (repartidores y ventas, «de día»): offline, notificaciones, bloqueo de versiones |
| [docs/ios-en-mac.md](docs/ios-en-mac.md) | Publicar la app de iPhone desde un Mac |
| [Canvas «Ottos · Panel web»](https://claude.ai/artifact/2j4t789enmGcFDE9Mj7NCy) | Diseño de cada pantalla del panel (Claude Design), igual que las vistas reales |
| [Canvas «Ottos · App móvil»](https://claude.ai/artifact/TRmZxFgFDxUGkaEDRHqh6F) | Diseño de cada pantalla de la app, igual que las vistas reales |
| `../ottos/docs/contracts/*.md` | Contratos de API acordados con el backend (offline-sync, app-version, monthly-report…) |

## Reglas de trabajo

- **Git Flow** (STANDARDS.md): nunca commit directo en `main` ni `develop`. `feature/`, `fix/` y `docs/` se fusionan
  con `--no-ff` en `develop` y se suben. A `main` solo llegan `release/` y `hotfix/`, con tag. Conventional Commits
  en inglés.
- **Antes de fusionar**: `flutter analyze` y `flutter test --exclude-tags integration` en verde en
  `packages/ottos_core`, `apps/ottos_ops` y `apps/ottos_courier`. Actualizar `CHANGELOG.md` (`[Unreleased]`),
  `roadmap.md` y, si hubo una decisión, `docs/decisiones.md`.
- **Cambios visuales**: actualizar en la misma rama el canvas oficial del cliente («Ottos · Panel web» o «Ottos · App
  móvil») para que coincida con lo implementado (STANDARDS.md › Canvas de diseño). Solo esos dos canvas: las variantes
  para decidir van en uno temporal que se borra cuando el usuario elige.
- **Idioma**: interfaz y documentación de producto en español; código, commits y READMEs técnicos en inglés.
- **No publicar una versión** (rama `release/`, tag, APK/AAB, TestFlight) sin el «sí» explícito del usuario.

## Otros agentes

Hay tres sesiones de Claude trabajando en paralelo y se hablan con mensajes entre sesiones:

- **Backend** (`ottos-backend`, repo `../ottos`): los contratos de API se cierran con él y se escriben en su repo.
  Los errores del backend se le reportan a él; aquí no se toca su código.
- **Infraestructura** (`ottos infraestructura`): Railway, dominios, variables de entorno, staging y producción. Desde
  aquí no se configura Railway.
- Al publicar una versión móvil hay que enviar al backend la plataforma, el build, el nombre de la versión, si es
  obligatoria y las notas. El backend las publica con una migración y así se activa el aviso o el bloqueo.

## Seguridad

- No imprimir secretos. La contraseña del admin local solo se lee con
  `grep -E '^OTTOS_ADMIN_PASSWORD=' ../ottos/.env`.
- Credenciales de prueba locales en `.env.local` y de staging en `.env.staging.local` (los dos ignorados por git).
- **Nunca escribir contraseñas de staging o producción en un navegador o emulador**: los entornos remotos se prueban
  por API con scripts. Producción solo tiene el admin del usuario y bloquea 15 minutos tras 5 fallos: nada de intentos
  inventados. No cambiar la contraseña del admin.
- La clave de firma de Android está en `~/.ottos-release/`, fuera del repo; `apps/ottos_courier/android/key.properties`
  está ignorado por git.

## Entornos

| Entorno | API | Panel |
| --- | --- | --- |
| Local | `http://localhost:8080` (`10.0.2.2:8080` desde el emulador Android) | `http://localhost:5050` |
| Staging | ver `.env.staging.local` | panel-staging |
| Producción | `https://api.remesadeotto.com` | `https://panel.remesadeotto.com` |

Backend local: `docker compose up -d postgres` y `./gradlew bootRun --args="--spring.profiles.active=dev"` en
`../ottos`. Ojo: el backend lee las versiones de la app (`app_releases`) una sola vez al arrancar; tras insertar una
fila hay que reiniciarlo.
