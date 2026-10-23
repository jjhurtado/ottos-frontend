# Changelog

Cambios notables del frontend de Ottos (panel de operaciones y app de repartidores) por versión. Formato basado en
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado según
[roadmap.md › Versionado](roadmap.md#versionado). Cómo y cuándo se escribe: [STANDARDS.md](STANDARDS.md#changelog).

## [Unreleased]

Las remesas por la casa necesitan el backend con la migración `V3` (en staging desde el 2026-10-23). Con un backend
anterior no aparece nada nuevo y todo funciona como antes. La app no exige actualizar: una versión antigua simplemente
no muestra la insignia.

### Añadido

- Panel y app › Nueva remesa: casilla **«Por la casa (sin comisión)»** en las entregas, solo para quien tiene el permiso «Registrar entregas por la casa». Al marcarla pide un motivo (obligatorio, hasta 500 caracteres), el resumen se recalcula con comisión 0, total igual al monto y la «Comisión no cobrada», y el botón pasa a «Registrar por la casa». La tasa y el monto mínimo son los de siempre. No se puede marcar ni desmarcar después de registrarla. Las recogidas no la tienen.
- Panel › Remesas: insignia «Por la casa» en el listado y en el detalle; el detalle muestra además la comisión no cobrada y el motivo. Nuevo filtro «Solo por la casa».
- App › remesas: insignia «Por la casa» en la lista y en el detalle, también para el repartidor.
- Panel › Reportes: el resumen mensual y su PDF muestran el bloque «Por la casa» con las comisiones no cobradas, cuántas entregas fueron y cuánto se envió (sin anuladas).
- Panel › Auditoría: la acción «Remesa por la casa (sin comisión)», con el monto, remitente, beneficiario, comisión no cobrada y motivo; también en el filtro de acciones.
- Panel › Roles: el permiso nuevo se llama «Registrar entregas por la casa (sin comisión)». Quien lo recibe tiene que salir y volver a entrar.

## [1.0.0-rc.7] - 2026-10-22

Funciona con el backend 1.0.0-rc.5; la acción «Completada desde el negocio» de Auditoría solo aparece con el backend
1.0.0-rc.6, que es el que la registra. Se publica el panel web. La app del móvil pasa a la compilación 9 (solo cambia
para ventas), pero esa compilación todavía no se ha distribuido.

### Añadido

- Panel › Auditoría: la acción «Completada desde el negocio» (con el backend que la registra), con el tipo, el importe, si se le quitó al repartidor y la nota. También está en el filtro de acciones.
- App › lista de ventas: opción **«Completadas»** junto a «Del día» y «Más atrasadas primero». Sin marcar, la lista es la de siempre. Marcada, debajo de las pendientes salen las entregadas y recogidas, de la más reciente a la más antigua, con «Completada el …» y «Entregado:» o «Recogido:»; «Ver más» trae las 50 siguientes. Se ve aunque no quede nada pendiente. El repartidor no la tiene.

### Corregido

- Panel en el móvil: los botones de cada pantalla van debajo del título (antes lo aplastaban letra a letra); Clientes, Beneficiarios, Usuarios y el efectivo de los repartidores se ven como listas en vez de tablas cortadas; Reportes muestra sus tablas como filas sin scroll lateral; en Remesas los filtros se pliegan bajo «Filtros»; en Caja cada moneda ocupa una fila y los movimientos muestran el importe bajo el título. En el ordenador no cambia nada.

## [1.0.0-rc.6] - 2026-10-14

Necesita el backend 1.0.0-rc.5 (entregar o recoger desde el negocio; las listas por páginas ya venían en la rc.4). Solo
cambia el panel web: la app del móvil no tiene cambios y no hay compilación nueva de Android ni de iPhone.

### Añadido

- Panel › detalle de remesa: botón **«Entregada por el negocio»** («Recogida por el negocio» en las recogidas) para ventas y el admin, en remesas abiertas, asignadas o no. Pide confirmación con una nota opcional y no pide PIN. El dinero sale de la caja del negocio en las entregas (aunque quede en negativo) y entra en ella en las recogidas; si tenía repartidor, se le quita. Después, el detalle dice «Entregada por el negocio» y el listado, «El negocio». Ventas lo ve tras volver a entrar en el panel.
- Panel › Clientes y Beneficiarios: las listas van por páginas de 50, como Remesas, con el total al pie («1–50 de 339») y flechas para pasar de página. Con una búsqueda, el total es el de los que coinciden y se vuelve a la primera página. Antes solo se veían los 50 más recientes o los 50 primeros que coincidían.

## [1.0.0-rc.5] - 2026-10-13

Necesita el backend 1.0.0-rc.4 (informe mensual con la moneda del negocio). Compilación 7 en Android e iPhone.

### Cambiado

- Panel › Reportes: el informe mensual y su PDF leen «Entregado» con el nombre nuevo del backend 1.0.0-rc.4 y muestran los importes en la moneda del negocio que indica el backend (USD en esta instalación). Sigue funcionando con el backend 1.0.0-rc.3.

## [1.0.0-rc.4] - 2026-10-13

Necesita el backend 1.0.0-rc.3 (remesas anuladas y remesas antiguas a mano). Compilación 6 en Android e iPhone (la rc.3
de iPhone ya usó la 5).

### Añadido

- Panel: el admin puede **anular** una remesa desde su detalle, en cualquier estado y con un motivo obligatorio. La remesa queda guardada con «Anulada por …», la fecha y el motivo, pero deja de contar en reportes, estadísticas y listas de trabajo y ya no se puede cambiar. Si movió efectivo, se devuelve solo a la caja de donde salió («Anulación de remesa»). En el listado de remesas, las anuladas llevan el chip «Anulada» y el filtro «Solo anuladas» las muestra. En Auditoría queda «Remesa anulada» con el motivo.
- App: una remesa anulada muestra por qué y no ofrece acciones; ventas no la ve en su lista de remesas.
- Panel: el admin puede **registrar una remesa antigua** a mano desde Remesas › «Registrar remesa antigua», con los datos de su ticket: entrega o recogida, remitente (o «Cliente histórico sin identificar»), beneficiario, fecha y hora, monto y comisión en USD y, si se entregó en CUP, la tasa y los CUP entregados tal cual. Queda entregada o recogida en esa fecha, sin repartidor y sin mover ninguna caja, y se abre su detalle.

## [1.0.0-rc.3] - 2026-10-13

Necesita el backend 1.0.0-rc.2 (aviso de versiones y caja del negocio sin cobros). Con el backend 1.0.0-rc.1 funciona,
pero sin avisos de versión.

### Añadido

- App: avisa cuando hay una versión nueva y, si la instalada ya no sirve, muestra «Actualiza para continuar» y no deja seguir trabajando. Antes de bloquear envía lo que tenga pendiente sin conexión.
- Panel y app: el menú de la cuenta (donde se cierra sesión) muestra al final la versión que está funcionando.
- App: ventas puede crear un remitente nuevo y un beneficiario nuevo al registrar una remesa, sin pasar por el panel.
- App: en «Caja», ventas puede tocar a un repartidor para ver su saldo y todos sus movimientos, como los ve él en «Mi caja», y desde ahí entregarle fondos o registrar una devolución.
- Panel: nueva sección «Beneficiarios» con todos los beneficiarios, también los que no tienen cliente (por ejemplo, los importados sueltos). Se buscan por nombre o teléfono, se editan y se crean sin cliente.
- App: al crear un remitente o un beneficiario, «Elegir de contactos» abre los contactos del teléfono para buscar a la persona y rellena su nombre y su teléfono. La app no pide permiso para leer la agenda: solo recibe el contacto que eliges.

### Cambiado

- Panel › Caja: la caja del negocio explica qué cuenta. Es el efectivo disponible en Cuba para las entregas: sube con depósitos y devoluciones de repartidores, y baja con fondos y retiros. Registrar una remesa ya no suma a la caja, porque se cobra fuera; lo cobrado está en Reportes. Necesita el backend con este cambio.
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
