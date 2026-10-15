# Estándares del proyecto

Cómo trabajamos en el frontend de Ottos: el flujo de Git y la arquitectura de las apps. Toda contribución, de personas o
de agentes, sigue este documento. Las reglas de Git son las mismas que en el backend
([jjhurtado/ottos](https://github.com/jjhurtado/ottos), `STANDARDS.md`). Si algo no encaja, se cambia aquí primero y después en el código.

## 0. Qué se consulta con el usuario

Regla del usuario (D-026), por encima de la «luz verde» que da para trabajar sin supervisión y en cualquier entorno
(local, staging o producción). Hay que preguntarle **antes** de:

- Cambiar algo que ya existe: reglas, cálculos, validaciones o flujos del panel y de la app.
- Ejecutar cualquier código o script que cree, cambie o borre datos en la base de datos.

No hace falta preguntar para funcionalidades nuevas que no tocan lo existente. Publicar en producción sigue necesitando
su orden explícita, aparte de esta consulta.

## 1. Git

### Flujo de ramas: Git Flow (configuración de GitKraken)

Usamos Git Flow tal como lo inicializa GitKraken (Preferences → Gitflow), con esta configuración guardada en el repo
(`git config --get-regexp gitflow`):

| Rama o prefijo | Valor | Para qué |
| --- | --- | --- |
| Rama de producción | `main` | Solo versiones publicadas; cada merge a `main` lleva un tag de versión |
| Rama de desarrollo | `develop` | Integración del trabajo terminado; de aquí salen las releases |
| Features | `feature/` | Funcionalidad o refactor nuevo; sale de `develop` y vuelve a `develop` |
| Arreglos y documentación | `fix/`, `docs/` | Igual que `feature/` (salen de `develop` y vuelven a `develop`), para un arreglo que no es urgente en producción o solo documentación |
| Releases | `release/` | Preparar una versión (subir número, últimos arreglos); sale de `develop`, se fusiona en `main` y en `develop` |
| Hotfixes | `hotfix/` | Arreglo urgente de producción; sale de `main`, se fusiona en `main` y en `develop` |
| Prefijo de tag | *(vacío)* | Los tags son la versión tal cual: `1.0.0-beta.1`, `1.0.0` |

Reglas:

- Nunca se hace commit directo en `main` ni en `develop`: todo entra por una rama `feature/`, `fix/`, `docs/`, `release/` o `hotfix/`, fusionada con `--no-ff`.
- Una rama, un propósito. Si aparece otro tema, va en otra rama.
- Antes de fusionar: análisis y tests en verde en cada paquete (`flutter analyze` y
  `flutter test --exclude-tags integration` en `packages/ottos_core`, `apps/ottos_ops` y `apps/ottos_courier`) y la rama
  actualizada con su rama base.
- Al cerrar una release o un hotfix se crea el tag de la versión en `main` (GitKraken lo hace al terminar el flujo).
- Las ramas terminadas se borran.

### Nombres de rama

`<prefijo>/<descripcion-corta>`, en minúsculas y con guiones; si hay ticket, va delante de la descripción.

- `feature/customers`, `feature/ottos-42-cash-page`
- `release/1.0.0-beta.2`, `release/1.0.0`
- `hotfix/1.0.1`, `hotfix/login-loop`

Sin espacios, mayúsculas, guiones bajos ni nombres de personas.

### Mensajes de commit

> **Pendiente de confirmar.** El estándar de referencia es el artículo
> [Git Branch Naming and Commit Best Practices Cheatsheet](https://medium.com/@mandolkarmakarand94/git-branch-naming-and-commit-best-practices-cheatsheet-875316b9ca20),
> que no se pudo leer desde el entorno de Claude (Medium lo bloquea). Lo de abajo es la convención habitual de ese tipo
> de guías (Conventional Commits); hay que contrastarlo con el artículo y ajustar lo que difiera.

```
<tipo>(<ámbito opcional>): <resumen en imperativo, minúsculas, sin punto, ≤ 72 caracteres>

<cuerpo opcional: qué cambia y por qué, líneas de ≤ 72 caracteres>

<pie opcional: BREAKING CHANGE: …, Refs: #42, Co-Authored-By: …>
```

| Tipo | Uso |
| --- | --- |
| `feat` | Funcionalidad nueva |
| `fix` | Corrección de un error |
| `refactor` | Cambio de código que no altera el comportamiento |
| `perf` | Mejora de rendimiento |
| `test` | Tests nuevos o corregidos |
| `docs` | Solo documentación |
| `style` | Formato, sin cambio de lógica |
| `build` | `pubspec.yaml`, dependencias, versión, configuración de plataforma |
| `ci` | Pipelines |
| `chore` | Mantenimiento que no encaja en lo anterior |

El ámbito es el área afectada: `core`, `auth`, `remittances`, `customers`, `cash`, `rates`, `users`, `roles`, `courier`…
Ejemplos:

- `feat(remittances): register, assign, deliver and postpone in the panel`
- `fix(core): keep the route when reloading a page`
- `test(customers): cover the customer detail cubit`
- `docs: add project standards`

Un commit, un cambio lógico; el build debe pasar en cada commit. Los mensajes se escriben en inglés, como el código.

### Versionado

Ver [roadmap.md › Versionado](roadmap.md#versionado). La versión vive en el `pubspec.yaml` de cada app y de `ottos_core`
(`version: …`, la misma en los tres; en las apps con `+<build>`) y se sube en la rama `release/` o `hotfix/`
correspondiente.

### Changelog

`CHANGELOG.md` sigue el formato [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Está escrito para quien usa
las apps (operaciones, ventas, repartidores, quien revisa una versión), no repite los commits: cuenta qué cambia para
ellos.

Categorías, en este orden y solo las que tengan entradas:

| Categoría | Qué va |
| --- | --- |
| `Añadido` | Pantalla o funcionalidad nueva |
| `Cambiado` | Cambio en algo existente (comportamiento, pantalla, flujo) |
| `Obsoleto` | Lo que se va a quitar en una versión próxima |
| `Eliminado` | Lo que se quitó |
| `Corregido` | Errores arreglados |
| `Seguridad` | Arreglos o cambios de seguridad |

Cada entrada es una línea en español que empieza por lo afectado (app y pantalla), dice qué cambia y, si rompe algo,
empieza por **Incompatible:** y explica qué hay que hacer (por ejemplo, la versión mínima del backend). Ejemplo:

```markdown
### Añadido
- Panel › Remesas: registrar, asignar, entregar y aplazar remesas desde el panel.

### Corregido
- Panel y app de repartidores: al caducar la sesión, la app vuelve al login en vez de quedarse cargando.
```

**Al fusionar una `feature/` en `develop`:** la propia rama, antes del merge, añade sus entradas bajo `## [Unreleased]`
en la categoría que corresponda. Si la feature no cambia nada visible para quien usa las apps (tests, documentación
interna, refactor sin efecto), no añade entrada. Quien revisa el merge comprueba que la entrada existe y se entiende.

**Al fusionar `develop` en `main` (rama `release/`):** en la rama `release/<versión>`:

1. Se renombra `## [Unreleased]` a `## [<versión>] - <AAAA-MM-DD>` (fecha del merge a `main`) y se revisan y
   ordenan las entradas acumuladas.
2. Se añade encima un `## [Unreleased]` nuevo y vacío.
3. Se sube la versión en los `pubspec.yaml` a la misma `<versión>`.
4. Al terminar la release, `main` recibe el tag `<versión>` y `develop` recibe el merge de vuelta.

**Al fusionar un `hotfix/` en `main`:** el hotfix añade directamente su sección `## [<versión de parche>] - <fecha>`
(por ejemplo `1.0.1`) con sus entradas en `Corregido` o `Seguridad`, debajo de `[Unreleased]`; al volver a `develop`
la sección queda también allí.

Nunca se editan las secciones de versiones ya publicadas.

Las reglas se aplican desde `1.0.0-rc.1`, la primera versión publicada; lo anterior no tiene entradas.

## 2. Arquitectura del frontend

### Monorepo

Workspace de Dart (`pubspec.yaml` raíz) con Melos para los scripts comunes:

| Paquete | Qué contiene | Depende de |
| --- | --- | --- |
| `packages/ottos_core` | Todo lo compartido: cliente de la API, sesión, modelos, repositorios, tema, textos comunes, widgets y diálogos | — |
| `apps/ottos_ops` | Panel de operaciones (Flutter Web) | `ottos_core` |
| `apps/ottos_courier` | App de repartidores (Android/iOS) | `ottos_core` |

Lo que usan las dos apps vive en `ottos_core`; una app nunca importa de la otra.

### Capas

```
Vista (page/dialog)  →  Cubit/Bloc  →  Repository  →  ApiClient  →  API
```

- **`ApiClient`** (`ottos_core`) es el único que habla HTTP: añade el token, lo refresca ante un 401 y convierte cada
  error en `ApiException`.
- **Repositorios** (`XRepository` en `ottos_core`): un método por endpoint, devuelven modelos, nunca JSON. Se crean una vez
  en `OttosScope` y se leen con `context.read<XRepository>()`.
- **Cubits/Blocs** (`features/<area>/cubit|bloc/`): estado de una pantalla, inmutable (`Equatable`), con un enum de
  estado (`loading`, `success`, `failure`). Capturan `ApiException` y guardan su `message` para mostrarlo.
- **Vistas** (`features/<area>/view/`): solo pintan el estado y llaman al cubit; sin llamadas a la API salvo en
  diálogos de formulario autocontenidos (guardan y devuelven el resultado).

### Modelos

- Clases inmutables con `fromJson` tolerante a nulos (`json.dart`) y `Equatable`.
- Lo que se envía a la API es una clase `XInput` o `NewX` con `toJson` (los textos vacíos viajan como `null`).
- Dinero como `double` solo para mostrar; las cuentas las hace el backend (cotización, totales).

### Navegación y permisos

- `go_router` con un `redirect` que primero resuelve la sesión (`authRedirect`, conserva la ruta en `?from=`) y después
  los permisos. Una sección se ve solo con su permiso (`Destinations`); cada acción, solo si el usuario tiene el permiso
  y el workflow la permite desde el estado actual.
- Permisos, nunca roles: `user.can(Permissions.remittancesAssign)`.

### Textos y errores

- La interfaz está solo en español; el código, en inglés. Los textos van en `CoreTexts` (compartidos) u `OpsTexts` /
  `CourierTexts`, nunca sueltos en los widgets.
- Los errores del backend se traducen por su `code` estable (`CoreTexts.errorCodes`); si falta la traducción se usa el
  `detail` o un mensaje por código HTTP.

### Tests

- Unitarios y de widget en cada paquete (`mocktail` para los repositorios). Cada funcionalidad o corrección lleva su
  test; los tests existentes no se cambian para que pase un cambio de comportamiento sin acordarlo.
- Integración contra un backend en marcha en `packages/ottos_core/test/integration`, con la etiqueta `integration`:
  se saltan si no se definen `OTTOS_TEST_EMAIL` y `OTTOS_TEST_PASSWORD`. Escriben datos en la base de ese backend.
- `flutter analyze` sin avisos y tests en verde en los tres paquetes antes de fusionar.

## 3. Documentación

La documentación es el contexto de quien llegue después, persona o agente. Va en la misma rama que el cambio:

| Documento | Se actualiza cuando… |
| --- | --- |
| `CHANGELOG.md` | Cambia algo visible para quien usa las apps (ver [Changelog](#changelog)) |
| `roadmap.md` | Se termina, añade o descarta una tarea, o cambia la versión actual |
| `docs/decisiones.md` | Se toma una decisión de producto, plataforma o proceso: qué, cuándo y **por qué** |
| `README.md` de cada paquete | Cambia su estructura, cómo se ejecuta o se publica, o un mecanismo importante |
| `CLAUDE.md` | Cambian las reglas de trabajo, los entornos o la coordinación con otros agentes |
| Canvas de diseño (Claude Design) | Cambia algo visual en el panel o la app (ver abajo) |

### Canvas de diseño

Hay **un canvas oficial por cliente** en Claude Design, y solo esos dos:

| Cliente | Canvas |
| --- | --- |
| Panel web (`ottos_ops`) | «Ottos · Panel web»: https://claude.ai/artifact/2j4t789enmGcFDE9Mj7NCy |
| App móvil (`ottos_courier`) | «Ottos · App móvil»: https://claude.ai/artifact/TRmZxFgFDxUGkaEDRHqh6F |

Reglas:

- El canvas oficial refleja las vistas implementadas. Todo cambio visual (pantalla nueva, elemento añadido o quitado,
  textos, colores, orden) actualiza en la misma rama el artboard de esa pantalla, o añade uno si no está.
- Si lo implementado difiere del dibujo, se corrige el dibujo, no al revés. Para comprobarlo se capturan las vistas
  reales (panel en Chrome sin interfaz, app en el emulador) contra el backend local.
- Los elementos que se repiten son componentes del canvas (barra lateral del panel, barra inferior de la app) y las
  pantallas los importan: un cambio ahí se hace una sola vez.
- **No hay canvas extra.** Solo se crea otro para tomar una decisión (variantes para que el usuario elija); cuando
  decide, lo elegido pasa al canvas oficial y el canvas de la decisión **se borra**.

Los contratos de API no se escriben aquí: viven en el repo del backend (`docs/contracts/`) y se enlazan.

