# Changelog

Cambios notables del frontend de Ottos (panel de operaciones y app de repartidores) por versión. Formato basado en
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado según
[roadmap.md › Versionado](roadmap.md#versionado). Cómo y cuándo se escribe: [STANDARDS.md](STANDARDS.md#changelog).

## [Unreleased]

Necesita el backend con el aviso de versiones (develop 3439c3b o posterior).

### Añadido

- App: avisa cuando hay una versión nueva y, si la instalada ya no sirve, muestra «Actualiza para continuar» y no deja seguir trabajando. Antes de bloquear envía lo que tenga pendiente sin conexión.
- Panel y app: el menú de la cuenta (donde se cierra sesión) muestra al final la versión que está funcionando.
- App: ventas puede crear un remitente nuevo y un beneficiario nuevo al registrar una remesa, sin pasar por el panel.
- App: en «Caja», ventas puede tocar a un repartidor para ver su saldo y todos sus movimientos, como los ve él en «Mi caja», y desde ahí entregarle fondos o registrar una devolución.
- Panel: nueva sección «Beneficiarios» con todos los beneficiarios, también los que no tienen cliente (por ejemplo, los importados sueltos). Se buscan por nombre o teléfono, se editan y se crean sin cliente.
- App: al crear un remitente o un beneficiario, «Elegir de contactos» abre los contactos del teléfono para buscar a la persona y rellena su nombre y su teléfono. La app no pide permiso para leer la agenda: solo recibe el contacto que eliges.

### Cambiado

- App: el aviso de versión nueva y la pantalla «Actualiza para continuar» tienen un botón «Actualizar» (antes «Descargar», o un texto para pedir el enlace). Abre la versión nueva en Play Store o, en iPhone, en TestFlight.

### Corregido

- Panel: en Auditoría la fecha ya no se parte en varias líneas.
- Panel: al editar un cliente o un beneficiario, la pantalla muestra el cambio en cuanto guardas (antes, si solo cambiaba la dirección o el número de casa, había que recargar).
- App: la ventana para crear un remitente se llama «Nuevo remitente» (decía «Nuevo cliente»).
- App: el inicio de sesión dice «Repartos y ventas» en vez de «App de repartidores», porque la usan también ventas.

## [1.0.0-rc.2] - 2026-10-11

Necesita el backend 1.0.0-rc.1.

### Añadido

- Panel: se publica en su propio dominio (panel-staging y, en producción, panel.remesadeotto.com) y habla con el backend a través de ese mismo dominio.
- App de iPhone: se compila en la nube y se reparte por TestFlight.

### Cambiado

- App: se llama «Ottos» y su identificador pasa a ser com.remesadeotto.ottos en Android e iOS. **Incompatible:** quien tenga instalada una versión anterior de prueba debe desinstalarla e instalar esta; el teléfono la trata como otra app.
- App: apunta al backend de producción (api.remesadeotto.com).
- Panel: el texto usa siempre su propia fuente Roboto y no descarga nada de Google al abrirse (puede estar bloqueado desde Cuba).

### Corregido

- App: la versión publicada se quedaba en la pantalla de inicio; ahora abre aunque las notificaciones no puedan arrancar.
- App de iPhone: pide permiso para las notificaciones y explica para qué usa Face ID.

## [1.0.0-rc.1] - 2026-10-11

Primera versión candidata a producción. Necesita el backend 1.0.0-rc.1.

### Añadido

- Panel y app › Acceso: inicio de sesión con bloqueo tras varios intentos fallidos, «Recordar mi usuario», cambio de la propia contraseña y cierre de sesión en todos los dispositivos al cambiarla.
- App › Acceso: entrar con huella después de aceptarlo una vez; si la contraseña cambia, la pide de nuevo.
- Panel › Inicio: remesas abiertas por estado, atrasadas, con incidencia y para revisar.
- Panel › Remesas: listado con filtros y búsqueda, detalle con historial y movimientos de caja, registrar entregas y recogidas con su cotización, asignar y reasignar repartidor, entregar, aplazar, marcar incidencia y resolver revisiones con una nota.
- Panel y app › Recogidas: tasa y comisión propias de cada recogida; el repartidor solo recoge el monto y la tasa es informativa.
- App de día › Repartidor: sus remesas del día o las más atrasadas primero, llamar y escribir por WhatsApp al beneficiario, entregar con PIN, deslizar para marcar incidencia, aplazar y su caja con todos los movimientos.
- App de día › Ventas: todas las remesas abiertas, nueva remesa con repartidor, asignar desde el detalle y entregar o recibir efectivo de cada repartidor.
- App › Sin conexión: entregas, recogidas, incidencias y cambios de moneda se guardan en el teléfono, el saldo se mueve al momento y todo se envía solo al volver la red.
- App › Cambio de moneda: el repartidor registra USD ↔ CUP con la tasa del momento; una tasa lejos de la configurada queda para revisar en el panel.
- App › Notificaciones: remesa nueva para el repartidor y remesa entregada o recogida completada para ventas, mientras la app está abierta.
- Panel › Caja: caja del negocio, efectivo de cada repartidor, fondos, devoluciones, cambios de moneda en su nombre y cambios con tasa inusual para revisar.
- Panel › Clientes: fichas de clientes y beneficiarios, búsqueda, exportar e importar CSV con vista previa, e importar beneficiarios sin remitente; la primera remesa los vincula.
- Panel › Configuración: tasas y comisiones de entregas y recogidas, monto mínimo, días de entrega, tolerancia del cambio de moneda y calculadora.
- Panel › Reportes: resumen mensual de ventas (cobrado, entregado, diferencia, recogidas y ganancias) y su PDF en una página A4.
- Panel › Usuarios, Roles y Auditoría: alta, edición, desactivación y contraseña de usuarios, roles con permisos y registro de quién cambió qué.

[Unreleased]: https://github.com/jjhurtado/ottos-frontend/compare/1.0.0-rc.2...develop
[1.0.0-rc.2]: https://github.com/jjhurtado/ottos-frontend/compare/1.0.0-rc.1...1.0.0-rc.2
[1.0.0-rc.1]: https://github.com/jjhurtado/ottos-frontend/releases/tag/1.0.0-rc.1
