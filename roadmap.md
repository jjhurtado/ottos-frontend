# Ottos frontend · Roadmap

Actualizado: 2026-10-13

## Estado actual

**Publicado: `1.0.0-rc.2`** (2026-10-11), con el backend `1.0.0-rc.1`. El panel está en producción
(https://panel.remesadeotto.com) y en staging. La app «Ottos» se distribuyó como APK (Android) y por TestFlight (iOS),
apuntando a producción.

**En `develop`, para `1.0.0-rc.3`** (esperando al usuario por si entran más cambios): ventas crea remitentes y
beneficiarios desde la app, el aviso y bloqueo de versiones de la app, y la versión en el menú de la cuenta.

Falta para `1.0.0`:

- Publicar Android en Google Play (cuenta de Play Console) y confirmar cómo lo instalan los repartidores en Cuba (ver
  «Dependencias con el backend y preguntas abiertas»).
- Pasar al backend el enlace de TestFlight y el de Play Store para el aviso de versión.
- Probar la huella en un teléfono real.
- Gestionar la primera remesa real con las apps.

Las decisiones y sus motivos están en [docs/decisiones.md](docs/decisiones.md).

## Cómo se usa: la app de día, el panel de noche

Decisión del negocio (2026-10-10): durante el día, **ventas y repartidores trabajan con la misma app móvil**; por la noche, **ventas y admin entran al panel web** para revisar y tener más control. La app deja de ser solo «del repartidor»: lo que cada usuario ve depende de sus permisos, nunca del rol.

- [x] **Nueva remesa desde la app**: botón en la lista de remesas (con `remittances:create`). El mismo formulario que el panel: tipo, remitente, beneficiario, monto y moneda, con la cotización de su tipo (entrega o recogida).
- [x] **Asignar repartidor al crearla**, solo si el usuario tiene `remittances:assign`; si no, el campo no aparece.
- [x] **Caja desde la app**: entregar fondos y recibir devoluciones de un repartidor concreto (con `cash:write`). Quien no tiene el permiso ve solo su caja, como hoy.
- [x] **Caja de cada repartidor desde la app** (2026-10-13): en «Caja», ventas toca un repartidor y ve su saldo y sus movimientos, igual que él en «Mi caja» (`GET /cash/couriers/{id}`, `cash:read`, últimos 100, solo con conexión), con «Entregar fondos» y «Registrar devolución» (`cash:write`).
- [x] Ventas entra en la app (`remittances:read`): ve las remesas abiertas (las 100 últimas; el resto, en el panel) y la caja de los repartidores; el repartidor ve las suyas y su caja.
- [x] Nombre y presentación de la app pensados para ventas y reparto: se llama «Ottos» (`com.remesadeotto.ottos`).
- [x] **Cambio de moneda del repartidor** (`cash:exchange-own`): en «Mi caja», «Cambiar moneda» con dirección, monto, tasa obtenida (siempre CUP por 1 USD) y nota; funciona sin conexión y el saldo se mueve al momento. En el panel: «Registrar cambio» en nombre de un repartidor (`cash:write`), los cambios con tasa inusual (más allá de la tolerancia de Configuración, 20 % por defecto) en «Cambios de moneda para revisar» de Caja y en Inicio, con «Resolver» y nota (`cash:review`).
- [x] **Asignar desde el detalle en la app**: una remesa pagada sin repartidor muestra «Asignar a repartidor» a quien tiene `remittances:assign`.
- [x] **Importar y exportar clientes en CSV** (panel, solo ADMIN): «Exportar CSV» descarga todos los clientes con sus beneficiarios (una fila por beneficiario, `;` y UTF-8 para Excel); «Importar CSV» enseña una vista previa (nuevos, ya existentes y rechazados con su fila y motivo) y guarda solo al confirmar, en lotes de 500. Un cliente con dos direcciones son dos clientes con el mismo nombre y teléfono.
- [x] **Beneficiarios sin cliente** (2026-10-11): «Importar beneficiarios» en Clientes (panel, solo ADMIN) carga la lista suelta (p. ej. el chat de WhatsApp pasado a CSV) con vista previa; columnas `beneficiario_*` de «Exportar CSV», obligatorias `beneficiario_nombre`, `beneficiario_telefono`, `beneficiario_calle` y `beneficiario_municipio` (código o nombre). En la nueva remesa (panel y app), «Buscar otro beneficiario» busca entre todos; al registrar la remesa queda vinculado al remitente.
- [x] Alta de un beneficiario suelto desde el panel (`POST /beneficiaries`): «Nuevo beneficiario» en la sección «Beneficiarios».
- [ ] **Importar remesas antiguas** (`POST /api/v1/remittances/import`, contrato del backend `docs/contracts/historical-import.md`): falta decidir si es una pantalla del panel o un script de infraestructura. Aún no hace falta.
- [x] **Tasa de cada recogida**: campo «Tasa de esta recogida» en el alta de recogidas (panel y app), con la configurada de inicio; la cotización y el detalle marcan «indicada a mano». Pendiente del negocio: poner la comisión de recogida en 0 en Configuración › Recogidas si no deben dejar ganancia.
- [x] **Recordar usuario** en el login (app y panel): casilla «Recordar mi usuario», marcada por defecto; el correo se guarda en el almacenamiento seguro del dispositivo.
- [x] **Entrar con huella** (app): tras entrar con contraseña, la app pregunta si usar la huella la próxima vez; si se acepta, guarda las credenciales en el almacenamiento seguro (Keystore) y muestra «Entrar con huella». Si la contraseña cambia, las olvida y pide la nueva. Sin huella registrada en el teléfono no se ofrece. Probado en emulador sin huella; falta probar con huella en un teléfono real.
- [ ] Ajuste para dejar de usar la huella en un dispositivo (hoy: «Ahora no» al preguntar; se vuelve a preguntar en el siguiente login con contraseña).
- [x] **Alta de remitentes y beneficiarios desde la app** (2026-10-12): «Nuevo remitente» y «Nuevo beneficiario» en «Nueva remesa» con `customers:write`; los formularios se movieron a `ottos_core`.
- [ ] Decidir qué más de ventas necesita estar en la app de día (buscar remesas, reasignar) y qué se queda solo en el panel.

## Notificaciones de la app

Pedido por el negocio (2026-10-11): avisar en el teléfono **cuando un repartidor tiene una remesa nueva** y **cuando se entrega una remesa**.

- [x] Decidido (2026-10-11): la entrega de una remesa se avisa a **ventas**; la remesa nueva, al **repartidor** asignado.
- [x] Sin Firebase/FCM ni Google Play (pueden estar bloqueados desde Cuba): notificaciones **locales** que la app genera al consultar el servidor: al abrirla, al volver la red, al volver al primer plano y cada 2 minutos con la app abierta.
- [x] **Repartidor: remesa nueva.** Al sincronizar, las remesas que el teléfono no tenía avisan «Nueva entrega asignada» / «Nueva recogida asignada» (código, beneficiario, municipio). No avisa en la primera descarga tras el login ni de las que creó el propio usuario. Más de 3 a la vez, un solo aviso. Al tocarla se abre la remesa. Probado en el emulador.
- [x] **Ventas: remesa completada.** Con `remittances:read`, la app consulta `GET /remittances/completed?since=` (todas las remesas, recogidas incluidas) y avisa «Remesa entregada» / «Recogida completada» con quién la hizo; no avisa de las entregas propias. La primera consulta solo marca desde dónde empezar. Probado en el emulador contra el backend.
- [x] Permiso de notificaciones de Android 13+ pedido tras el login; dos canales («Remesas nuevas», «Remesas completadas») que se pueden silenciar desde los ajustes de Android.
- [ ] Con la app cerrada no hay avisos. Valorar una comprobación en segundo plano (Android WorkManager, mínimo ~15 min) y su consumo de batería y datos.
- [ ] Revisar `dependency_overrides: dbus` en el `pubspec.yaml` raíz cuando flutter_local_notifications acepte dbus 0.8.

## App sin conexión (offline-first)

Prioridad para la versión 1.0 (petición del negocio, 2026-10-10): hay días en que el repartidor pasa la jornada entera sin internet. El backend lo está diseñando (sección «App del repartidor offline-first» de su ROADMAP.md) y el contrato se cierra entre los dos agentes antes de implementarlo.

- [x] Contrato cerrado con el backend (2026-10-10, `ottos/docs/contracts/offline-sync.md`): `GET /sync/state?since=` y `POST /sync/actions` (lote de hasta 200, UUID por acción, `occurredAt`, resultados APPLIED/ALREADY_APPLIED/REJECTED con los mismos `code`), login con `client: MOBILE` (sesión de 14 h), `strictPin` para rechazar un PIN incorrecto cuando hay red, y revisión de remesas (`review`, `?review=true`, `POST /remittances/{id}/review/resolve`, permiso `remittances:review`). Implementado en el backend y en la app.
- [x] Guardar en el teléfono (SQLite) las remesas asignadas, la caja propia, el workflow y una cola de acciones pendientes (entregar con o sin PIN, aplazar, incidencia). La app abre sin red con el último usuario y no cierra la sesión si no llega al servidor.
- [x] Barra de sincronización (sin conexión, N sin enviar, sincronizado hace X, botón), chip «Sin enviar» en la tarjeta, lista «No sincronizadas» con el motivo en español, aviso «Para revisar», y aviso al cerrar sesión con acciones sin enviar.
- [x] Sincronizar al abrir la app, al recuperar la red, al volver al primer plano, al tirar de la lista y a mano. Con red y sin cola, la acción va directa con `strictPin` (un PIN incorrecto se rechaza al momento).
- [x] Ventas trabaja solo con conexión (crear remesas, asignar, mover caja); el repartidor, sin ella.
- [x] Panel: filtro y tarjeta «Para revisar», aviso en el detalle con «Resolver» (nota obligatoria, `remittances:review`) e historial con el motivo.
- [x] Probado en el emulador: entrega sin red, app cerrada y abierta sin red, envío automático al volver la red con la hora real, y PIN incorrecto sin red marcado PIN_MISMATCH.
- [ ] Valorar sincronización en segundo plano (hoy solo con la app abierta) y limpiar la cola si otro usuario entra en el mismo teléfono (hoy se avisa al cerrar sesión).

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
- [x] **Sección «Beneficiarios»** en el panel (2026-10-13): todos los beneficiarios, tengan cliente o no, con buscador por nombre o teléfono, edición y alta sin cliente (`customers:write`). Antes, los importados sueltos no se podían editar.
- [x] **Crear cliente o beneficiario desde «Nueva remesa»** sin salir del formulario; el nuevo queda elegido.
- [ ] Revisar en el navegador las pantallas de la ficha y los formularios (la extensión de Chrome no pudo hacer capturas; los tests de widget e integración pasan).
- [ ] **Eliminar y restaurar beneficiarios** (borrado lógico para todos los clientes) desde la sección «Beneficiarios»: el backend ya tiene `DELETE /beneficiaries/{id}` y `POST /beneficiaries/{id}/restore`. Aún no hace falta.
- [ ] **Ver qué clientes le envían a un beneficiario** en la sección «Beneficiarios» (`GET /beneficiaries/{id}` devuelve sus clientes). Aún no hace falta.
- [ ] Los tests de integración dejan clientes de prueba en la base local («Prueba Frontend Editada»); no hay endpoint para borrarlos. Valorar una base de datos aparte para tests.

Criterio de salida: se puede registrar un cliente nuevo con un beneficiario y usarlo en una remesa sin salir del panel.

## Fase 3 · Resto del panel

Objetivo: sustituir las pantallas «Próximamente» que quedan. Todas tienen el backend listo; el orden sigue lo que más se necesita en la operación diaria.

1. ~~**Caja**~~ Hecho: saldo del negocio y movimientos, saldo por repartidor, entregar fondos y recibir devoluciones de repartidores, depósitos y retiros, y movimientos de cada remesa en su detalle.
   - [ ] **Cuadre de caja del repartidor** (cierre diario): efectivo contado por moneda frente al saldo esperado, la diferencia, quién lo confirma e historial de cierres. El backend todavía no lo tiene; está en su Fase 3 («Caja y control»). Proponer adelantarlo.
2. ~~**Configuración**~~ Hecho (`/configuration`): ajustes generales (monto mínimo por remesa y días para entregar), corredores con tasa y comisión en vigor, historial de ambas, nueva tasa y nueva regla de comisión, y una calculadora. Sigue al módulo `configuration` del backend (`configuration:read` y `configuration:write`). Las recogidas tienen su propia tasa y comisión: cada corredor muestra Entregas y Recogidas por separado, y la calculadora y «Nueva remesa» cotizan con el tipo elegido. Ojo: la tasa inicial de recogida es 1; hay que poner la real en USD-CUP.
3. ~~**Usuarios**~~ Hecho: listado con búsqueda, alta con contraseña inicial y roles, edición de nombre y roles, restablecer contraseña, desactivar y reactivar.
4. ~~**Roles y permisos**~~ Hecho: roles con sus permisos por área y en español, alta, edición y eliminación; el rol del sistema es de solo lectura y solo se pueden dar permisos que uno tiene.
5. ~~**Mi cuenta**~~ Hecho: cambio de contraseña desde el menú de usuario del panel y el menú de cuenta de la app de repartidores; al cambiarla se cierra la sesión y el login explica por qué.
6. ~~**Registro de auditoría**~~ Hecho (`/audit`, `audit:read`, solo ADMIN): quién cambió qué y cuándo en usuarios y roles, filtros por tipo, acción y fechas, acciones, roles y permisos en español por su código, y «El sistema» para la creación del primer admin.
7. **Resumen mensual de ventas** (`/reports`, `reports:read`, ADMIN y SALES): remesas, total cobrado, total entregado (por moneda y en USD), diferencia y ganancias (comisiones), por moneda de entrega y por tipo, y estado al cierre; exportable a PDF A4 generado en el panel. Diseño aprobado en el canvas. Pantalla y PDF hechos con el contrato acordado (`ottos/docs/contracts/monthly-report.md`); probado contra el backend local con datos reales.

Los roles del sistema (ADMIN, SALES, DELIVERY) y los permisos se muestran en español, traducidos por su código; el backend los guarda en inglés.

Criterio de salida: no queda ninguna sección «Próximamente» en el menú y cada una respeta sus permisos.

## App courier

App «Ottos» para repartidores y ventas, probada en emulador contra el backend local y publicada en rc.2 (APK y TestFlight). Detalles técnicos en [apps/ottos_courier/README.md](apps/ottos_courier/README.md).

- [x] Probada en un emulador Android contra el backend local: login, lista, detalle, recoger, entregar con PIN (incorrecto y correcto), aplazar y Mi caja. Arreglos que salieron: fecha propuesta al aplazar, municipio repetido en la dirección, y entregas y recogidas diferenciadas por color e icono.
- [x] **Incidencias de entrega**: «No se pudo entregar/recoger» con motivo (nota obligatoria en «Otro motivo») en la app y en el detalle del panel; aviso en la lista de la app, en la lista y el detalle del panel; filtro «Con incidencia», tarjeta en Inicio e historial con el motivo. Motivos traducidos por código.
- [x] **Lista del repartidor**: las atrasadas y con incidencia van al final; orden «Más atrasadas primero» por días; días de atraso en la tarjeta; deslizar a la derecha para completar y a la izquierda para marcar una incidencia, siempre con confirmación; nombre del usuario en la barra; WhatsApp junto a Llamar; tras reportar una incidencia vuelve a la lista.
- [x] Estados traducidos por código y tipo: una recogida completada dice «Recogida» y una entrega «Entregada» (en listas, detalle, historial, chips de la app); en filtros e Inicio, «Entregada o recogida». `statusName` del backend queda como respaldo.
- [ ] Tests de los cubits de asignadas, remesa y caja.
- [x] Llamar y escribir por WhatsApp desde el detalle.
- [ ] Abrir la dirección en mapas desde el detalle.
- [x] Sin conexión: ver «App sin conexión (offline-first)».
- [x] Builds firmados de Android (APK por ABI, clave en `~/.ottos-release/`) e iOS (TestFlight desde el Mac del usuario). En rc.2 la APK se pasó por WhatsApp.
- [x] **Aviso y bloqueo de versiones** (contrato del backend `docs/contracts/app-version.md`): cabeceras `X-App-Platform` y `X-App-Build` en cada petición, aviso cerrable si hay versión nueva y pantalla fija si está por debajo de la mínima (o llega un 426), vaciando antes la cola sin conexión. Las APK separadas por ABI informan `abi*1000 + build`; la app usa el resto entre 1000.
- [x] **Botón «Actualizar»** en el aviso y en la pantalla de bloqueo: abre el `downloadUrl` del backend o, si no hay, Play Store (Android) o la app TestFlight (iPhone).
- [x] **Versión en el menú de la cuenta** (panel y app), elegida entre dos variantes en Claude Design.
- [x] **Canvas de diseño al día** (2026-10-13): «Ottos · Panel web» y «Ottos · App móvil», redibujados desde capturas de las vistas reales.
- [x] Panel › Auditoría: la fecha ya no se parte en cuatro líneas. App: el diálogo de «Nuevo remitente» se titula así y el login dice «Repartos y ventas» en vez de «App de repartidores».
- [x] **Elegir de contactos** al crear un remitente o un beneficiario en la app: abre el selector de contactos del teléfono (con su buscador) y rellena nombre y teléfono. No pide permiso de contactos: el sistema solo entrega el contacto elegido. El plugin (`flutter_native_contact_picker`) avisa de que usa el Kotlin antiguo de Gradle; vigilarlo al subir de Flutter.
- [ ] **Pasar iPhone de TestFlight a la App Store** (decidido 2026-10-13, sin fecha). Al hacerlo: cambiar el respaldo de «Actualizar» en `apps/ottos_courier/lib/app_update/update_gate.dart` (`itms-beta://`) por el enlace de la App Store, dar ese enlace al backend como `downloadUrl` de iOS y actualizar `docs/ios-en-mac.md`.
- [ ] Publicar Android en Play Store (decidido 2026-10-12) y dar al backend el enlace de Play Store y el de TestFlight como `downloadUrl`.

## Calidad e infraestructura

- [ ] Arreglar los scripts de Melos: hoy llaman a `melos`, que no está en el PATH; cambiarlos a `dart run melos` o ejecutar el comando directamente.
- [ ] CI en GitHub Actions: `flutter analyze` y `flutter test` en cada push; los tests de integración en un job aparte con el backend en Docker.
- [ ] Tests de widget de cada pantalla nueva y de los cubits/blocs del panel.
- [x] Build de producción del panel: imagen Docker con Caddy en su propio dominio, que reenvía `/api` al backend (sin CORS).
- [x] Variables por entorno (`OTTOS_API_URL`) documentadas para desarrollo, pruebas y producción (README y CLAUDE.md).

## Prueba general de 1.0 (2026-10-11)

Recorrido completo con ventas, dos repartidores y admin contra el backend 1.0.0-rc.1, documentado en «Prueba general de Ottos 1.0» (Claude Docs). 68 pruebas: todas en OK salvo las que necesitan algo que no hay en local (huella en un teléfono real, monto mínimo configurado, cuatro avisos a la vez, alta de beneficiarios desde la ficha y cambio de moneda desde el panel), cubiertas por tests. Fallos encontrados y arreglados: pantalla roja en Inicio y al cerrar sesión en 11 pantallas, PIN corto sin explicación, saldos en rojo de más, auditoría de importaciones en inglés, recogidas que «entregaban», totales del informe y tablas del PDF; del backend: admin como repartidor, repartidor sin movimientos fuera de Caja y sesiones de usuarios desactivados.

- [ ] Probar la huella (A4, A5) en un teléfono real con huella registrada.

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

**Versión actual: `1.0.0-rc.2`** (2026-10-11), con el backend `1.0.0-rc.1`.

Decidido (2026-10-11): los arreglos que salgan de la prueba en staging van en `1.0.0-rc.2` (rama `release/1.0.0-rc.2`); el tag `1.0.0-rc.1` publicado no se toca. Si staging no encuentra nada, se pasa de `1.0.0-rc.1` directamente a `1.0.0`. El backend versiona igual.

## Dependencias con el backend y preguntas abiertas

- **Cambio incompatible del backend (resuelto):** las tasas y comisiones se movieron a `/api/v1/configuration/…` y `rates:write` se sustituyó por `configuration:read` y `configuration:write`. El frontend ya lo sigue. Las sesiones iniciadas antes del cambio tienen los permisos viejos y deben volver a entrar.
- **Roles personalizados sin `configuration:read`:** no pueden listar las monedas al crear una remesa. Hoy ADMIN y SALES lo tienen; si se crea un rol que registra remesas, hay que darle también `configuration:read`.

- ~~**Lista de repartidores para asignar.**~~ Resuelto: `GET /couriers` con `remittances:assign`. Incluye al admin porque tiene todos los permisos; decidir si el panel lo oculta.
- ~~**Respuesta 401 sin cuerpo.**~~ Resuelto: 401 y 403 traen `ProblemDetail`.
- ~~**Errores de negocio en inglés.**~~ Resuelto: todos los errores traen un `code` estable y `CoreTexts.errorCodes` traduce los del flujo de remesas y clientes. Añadir traducciones a medida que se usen más códigos.
- **Google Play en Cuba (abierto, 2026-10-13).** Se decidió distribuir Android por Play Store, pero Google Play no está disponible en Cuba, y las notificaciones y la fuente se diseñaron precisamente para no depender de Google. Antes de publicar, confirmar con el usuario dónde están los repartidores y cómo instalarán la app (cuenta de Google de fuera, VPN, o mantener la APK como alternativa).
- **Monedas destino.** ¿Qué monedas se ofrecen al crear una remesa: se leen de los corredores (`/corridors`) o son fijas?
- **Recogidas.** ¿Quién crea las remesas de tipo recogida y qué datos financieros debe ver cada rol? Ya tienen tasa y comisión propias en el backend.
- ~~**Estados por tipo.**~~ Hecho: `CoreTexts.statusName(code, type:)`.
