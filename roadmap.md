# Ottos frontend · Roadmap

Actualizado: 2026-10-09

## Estado actual

El panel de operaciones hoy es de solo lectura: login, inicio, listado y detalle de remesas. No puede crear, asignar ni entregar remesas, y Clientes, Tasas, Caja, Usuarios y Roles son pantallas «Próximamente». El backend ya expone casi todos los endpoints necesarios, así que el grueso del trabajo está en el frontend.

| Área | Panel (web) | App courier | Backend |
| --- | --- | --- | --- |
| Login, sesión, refresco de token | Funciona (probado en Chrome) | Funciona (tests de widget) | Listo |
| Inicio con contadores | Funciona | — | Listo |
| Listado y filtros de remesas | Funciona | Lista de asignadas | Listo |
| Detalle e historial de remesa | Funciona | Funciona | Listo |
| Crear remesa | No existe | — | `POST /remittances` |
| Asignar repartidor | No existe | — | `POST /remittances/{id}/assign` |
| Entregar o posponer | No existe | Existe, sin probar en dispositivo | `deliver`, `deliver-with-pin`, `postpone` |
| Clientes y beneficiarios | «Próximamente» | — | CRUD completo + búsqueda |
| Tasas y comisiones | «Próximamente» | — | Corredores, tasas, reglas de comisión, cotización |
| Caja | «Próximamente» | Saldo propio | Negocio, repartidores, movimientos |
| Usuarios y roles | «Próximamente» | — | CRUD completo + permisos |

Ya corregido (pendiente de commit): sesión caducada que dejaba la app colgada, recarga de página que perdía la ruta, flecha suelta en el historial y test de plantilla roto en la app courier.

## Fase 1 · Flujo de remesas en el panel

Objetivo: que una persona de ventas registre una remesa, un supervisor la asigne y el repartidor la entregue, todo desde las apps y sin tocar la API a mano. Es la prioridad porque es el núcleo del negocio y el backend ya lo soporta.

- [x] **Crear remesa** (`/remittances/new`): tipo, remitente (búsqueda), beneficiario, monto y moneda destino, con la cotización antes de confirmar y `Idempotency-Key` para no duplicar con doble clic o reintento. Por ahora solo elige clientes y beneficiarios existentes; darlos de alta desde el formulario queda en la Fase 2.
- [x] **Asignar y reasignar repartidor** desde el detalle, con `GET /couriers` (remesas abiertas de cada uno) y nota opcional.
- [x] **Entregar desde el panel** (con o sin PIN) y **aplazar** con nueva fecha y motivo. Los diálogos ahora están en `ottos_core` y los comparten panel y app courier.
- [x] **Botones según el workflow**: solo las transiciones que `GET /remittance-workflow` permite desde el estado actual y con los permisos del usuario.
- [x] **Mensajes de éxito y error** tras cada acción; el detalle recarga remesa e historial. Los errores del backend se traducen por su `code`.
- [ ] Al volver al listado o al inicio después de una acción, comprobar que muestran el estado nuevo (hoy se recargan al entrar).
- [x] **Prueba de extremo a extremo** automatizada (`packages/ottos_core/test/integration`): cotizar → crear (reintento idempotente) → asignar → PIN incorrecto rechazado → entregar → historial.
- [ ] **Prueba en el navegador** del recorrido completo con tres usuarios: ventas, supervisor y repartidor (en la app courier). Hoy solo hay usuario admin y dos repartidores de prueba.

Criterio de salida: el recorrido completo funciona en Chrome con tres usuarios de roles distintos y queda cubierto por un test automatizado.

## Fase 2 · Clientes y beneficiarios

Objetivo: gestionar clientes y sus beneficiarios desde el panel. Va en paralelo con la Fase 1, porque crear una remesa necesita elegir ambos. El backend ya tiene CRUD y búsqueda (`?q=`); en el frontend falta todo, empezando por los modelos y un `CustomerRepository` en `ottos_core`.

- [x] **Modelos y repositorios** en `ottos_core`: cliente, beneficiario, estadísticas, provincias y municipios (`CustomerRepository`, `ZoneRepository`).
- [x] **Listado de clientes** (`/customers`) con búsqueda por nombre o teléfono.
- [x] **Alta y edición de cliente**, con validación de teléfono y el error de teléfono repetido en español.
- [x] **Ficha de cliente** (`/customers/{id}`): datos, estadísticas de remesas, beneficiarios, «Ver remesas» (listado filtrado por `customerId`) y «Nueva remesa» con el cliente ya elegido.
- [x] **Beneficiarios**: alta, edición y desvinculación dentro de la ficha del cliente, con selector de provincia y municipio.
- [x] **Crear cliente o beneficiario desde «Nueva remesa»** sin salir del formulario; el nuevo queda elegido.
- [ ] Revisar en el navegador las pantallas de la ficha y los formularios (la extensión de Chrome no pudo hacer capturas; los tests de widget e integración pasan).
- [ ] Los tests de integración dejan clientes de prueba en la base local («Prueba Frontend Editada»); no hay endpoint para borrarlos. Valorar una base de datos aparte para tests.

Criterio de salida: se puede registrar un cliente nuevo con un beneficiario y usarlo en una remesa sin salir del panel.

## Fase 3 · Resto del panel

Objetivo: sustituir las pantallas «Próximamente» que quedan. Todas tienen el backend listo; el orden sigue lo que más se necesita en la operación diaria.

1. **Caja**: saldo del negocio y movimientos, saldo por repartidor, entregar fondos y recibir devoluciones de repartidores, depósitos y retiros, y movimientos de cada remesa en su detalle.
2. **Tasas y comisiones**: corredores, historial de tasas, alta de tasa nueva y reglas de comisión.
3. **Usuarios**: listado, alta, edición, roles, activar o desactivar y restablecer contraseña.
4. **Roles y permisos**: listado, alta y edición de roles con la matriz de permisos.
5. **Mi cuenta**: cambio de contraseña (el repositorio ya lo soporta; falta la pantalla en ambas apps).

Criterio de salida: no queda ninguna sección «Próximamente» en el menú y cada una respeta sus permisos.

## App courier

La app tiene lista de asignadas, detalle, entregar (con o sin PIN), posponer y saldo propio, pero nunca se ha ejecutado en un dispositivo ni contra el backend.

- [ ] Ejecutarla en un emulador Android contra el backend local (usa `10.0.2.2:8080`) y recorrer entregar y posponer con un repartidor real.
- [ ] Tests de los cubits de asignadas, remesa y caja.
- [ ] Llamar y abrir mapas desde el detalle (`url_launcher` ya está en las dependencias).
- [ ] Comportamiento sin conexión: mensaje claro y reintento, sin perder lo que el repartidor escribió.
- [ ] Builds firmados de Android e iOS y forma de distribuirlos a los repartidores.

## Calidad e infraestructura

- [ ] Commitear los arreglos y tests de esta sesión.
- [ ] Arreglar los scripts de Melos: hoy llaman a `melos`, que no está en el PATH; cambiarlos a `dart run melos` o ejecutar el comando directamente.
- [ ] CI en GitHub Actions: `flutter analyze` y `flutter test` en cada push; los tests de integración en un job aparte con el backend en Docker.
- [ ] Tests de widget de cada pantalla nueva y de los cubits/blocs del panel.
- [ ] Build de producción del panel (`flutter build web`) y dónde se sirve (mismo dominio que la API o CORS configurado).
- [ ] Variables por entorno (`OTTOS_API_URL`) documentadas para desarrollo, pruebas y producción.

## Versionado

Versionado semántico (`MAYOR.MENOR.PARCHE`) con etiquetas de pre-release, igual que el backend. La versión vive en el
`pubspec.yaml` de cada app y de `ottos_core` (la misma en los tres), se sube en la rama `release/` o `hotfix/` de Git Flow
y cada versión publicada lleva su tag en `main`, sin prefijo (`1.0.0-beta.1`). Detalles del flujo en
[STANDARDS.md](STANDARDS.md).

| Etapa | Formato | Significa | Qué entra |
| --- | --- | --- | --- |
| Beta | `1.0.0-beta.N` | Fase 1 en construcción; se prueba en local o staging, sin dinero real | Funcionalidad nueva, refactors y arreglos |
| Release candidate | `1.0.0-rc.N` | Fase 1 completa; candidata a producción | Solo arreglos |
| Estable | `1.0.0` | Primera remesa real gestionada con las apps | — |
| Parche | `1.0.X` | Arreglo urgente en producción (rama `hotfix/`) | Solo el arreglo |
| Menor | `1.X.0` | Cada fase siguiente, con su propio ciclo beta → rc → estable | Funcionalidad nueva compatible |
| Mayor | `X.0.0` | Cambio incompatible (por ejemplo, exige una versión nueva del backend) | Solo con migración planificada |

**Versión actual: `1.0.0-beta.1`.**

## Dependencias con el backend y preguntas abiertas

- ~~**Lista de repartidores para asignar.**~~ Resuelto: `GET /couriers` con `remittances:assign`. Incluye al admin porque tiene todos los permisos; decidir si el panel lo oculta.
- ~~**Respuesta 401 sin cuerpo.**~~ Resuelto: 401 y 403 traen `ProblemDetail`.
- ~~**Errores de negocio en inglés.**~~ Resuelto: todos los errores traen un `code` estable y `CoreTexts.errorCodes` traduce los del flujo de remesas y clientes. Añadir traducciones a medida que se usen más códigos.
- **Monedas destino.** ¿Qué monedas se ofrecen al crear una remesa: se leen de los corredores (`/corridors`) o son fijas?
- **Recogidas.** ¿Quién crea las remesas de tipo recogida y qué datos financieros debe ver cada rol?
