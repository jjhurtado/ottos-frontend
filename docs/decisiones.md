# Decisiones del frontend de Ottos

Registro de las decisiones que dan forma al proyecto: qué se decidió, cuándo y **por qué**. Sirve para no
volver a discutir lo ya resuelto y para saber qué hay que revisar si cambia el motivo. La más reciente va primero
dentro de cada bloque. Una decisión nueva se añade aquí en la misma rama que la implementa; si una anterior deja de
valer, se tacha y se enlaza la que la sustituye.

Fuentes: peticiones del dueño del negocio (el usuario), acuerdos con el agente del backend (repo `ottos`) y con el de
infraestructura (Railway, dominios).

## Producto

| Fecha | Decisión | Por qué |
| --- | --- | --- |
| 2026-10-14 | «Entregada por el negocio» va en el detalle de la remesa del panel, solo con `remittances:complete-from-business`, en remesas abiertas y no anuladas, con un diálogo que dice qué pasa con la caja y el repartidor. En la app no está. | Decisión del usuario (vía backend): ventas o el admin cierran remesas sin repartidor. Mueve la caja del negocio y quita la remesa al repartidor, así que se confirma antes; el usuario pidió cambios solo en el panel. |
| 2026-10-14 | Clientes y Beneficiarios van por páginas de 50 con el total al pie, como Remesas. Un beneficiario editado cambia en su sitio; uno nuevo vuelve a cargar la primera página. El buscador de «Nueva remesa» sigue pidiendo la lista sin `page`. | Con 339 beneficiarios reales la lista de 50 ya no bastaba (petición del usuario). Lo nuevo es lo más reciente, así que aparece arriba con el total correcto; la búsqueda del formulario solo necesita las primeras coincidencias. |
| 2026-10-13 | La versión en uso se muestra al final del menú de la cuenta, en el panel y en la app (se descartó un pie de pantalla siempre visible). | Saber qué versión tiene cada uno cuando reporta un problema, sin ocupar espacio en la pantalla principal. Elegido por el usuario entre dos variantes dibujadas en Claude Design. |
| 2026-10-12 | Ventas crea remitentes y beneficiarios nuevos desde «Nueva remesa» en la app (con `customers:write`). Los formularios viven en `ottos_core` y los comparten panel y app. | Ventas registra remesas de día con la app y no podía dar de alta a un cliente nuevo sin ir al panel. |
| 2026-10-11 | El admin no aparece en la lista de repartidores para asignar. | Tiene todos los permisos, así que el backend lo devolvía como repartidor; no reparte. Lo filtra el backend. |
| 2026-10-11 | Resumen mensual de ventas (cobrado, entregado, diferencia, ganancias = comisiones) exportable a PDF, generado en el panel. | Es el informe que el negocio necesita cada mes; generarlo en el panel evita depender de un servicio de PDF en el backend. |
| 2026-10-11 | El repartidor registra cambios de moneda USD ↔ CUP con la tasa que obtuvo; una tasa fuera de la tolerancia (20 % por defecto) queda «para revisar» en el panel. | El repartidor cambia dinero en la calle; su caja tiene que reflejarlo al momento y una tasa rara puede ser un error o un abuso. |
| 2026-10-11 | Cada recogida lleva su propia tasa (la configurada como propuesta, editable). | La tasa de una recogida se pacta caso a caso. |
| 2026-10-11 | Importar beneficiarios sueltos (sin remitente); la primera remesa los vincula. | El negocio tenía la lista de beneficiarios en un chat de WhatsApp, sin remitentes. |
| 2026-10-11 | Notificaciones: remesa nueva → al repartidor asignado; remesa entregada/recogida → a ventas. | Lo que cada uno necesita saber para actuar. |
| 2026-10-11 | Entrar con huella y «Recordar mi usuario» (credenciales en el almacenamiento seguro del teléfono). | Los repartidores entran muchas veces al día desde la calle. |
| 2026-10-10 | Deslizar a la izquierda marca una incidencia (antes aplazaba); a la derecha, completar. Siempre con confirmación. | La incidencia es lo que pasa en la calle («no estaba», «dirección mal»); aplazar es menos frecuente. |
| 2026-10-10 | Entregas y recogidas se distinguen por color e icono en toda la app. | En la lista del repartidor se confundían. |
| 2026-10-10 | **La app de día, el panel de noche:** ventas y repartidores usan la misma app móvil durante el día; ventas y admin revisan en el panel por la noche. Lo que se ve depende de los permisos, nunca del rol. | Así trabaja el negocio: ventas está en la calle o en el teléfono, no en un ordenador. |
| 2026-10-10 | **Offline-first para el repartidor**: entregas, recogidas, incidencias y cambios de moneda se guardan en el teléfono y se envían al volver la red. Ventas trabaja solo con conexión. | Hay días enteros sin internet en Cuba; el repartidor no puede dejar de trabajar. Contrato: `ottos/docs/contracts/offline-sync.md`. |
| 2026-10-10 | USD es la moneda propuesta al crear una remesa. | La mayoría de remesas son en USD. |
| 2026-10-09 | Roadmap por fases: primero el flujo de remesas en el panel (crear → asignar → entregar), luego clientes, luego el resto. | Era lo que no funcionaba y es el núcleo del negocio. |

## Plataforma y distribución

| Fecha | Decisión | Por qué |
| --- | --- | --- |
| 2026-10-13 | En iPhone se compila con `--build-name` igual a la versión sin etiqueta (`1.0.0-rc.3` → `1.0.0`) y sin tocar el número de compilación. La rc.3 de iPhone salió como compilación **5** (la 4 la usó una prueba con el código de la rc.2), así que la próxima versión usa `+6` o más; los tags publicados no se tocan. | iOS solo admite hasta tres números en la versión y Flutter convertía `1.0.0-rc.3` en `1.0.0.3`, que App Store Connect rechaza. El número de compilación es el que compara el aviso de versiones, y TestFlight no acepta repetirlo. |
| 2026-10-13 | La **caja del negocio** es el efectivo disponible en Cuba para las entregas. Registrar o importar una remesa no la mueve (ya no hay `REMITTANCE_PAYMENT`). Sube con depósitos y devoluciones, y baja con fondos y retiros. Lo cobrado se ve en Reportes. | Decisión del usuario, aplicada en el backend: los remitentes pagan fuera de Cuba, así que ese dinero nunca estuvo en esta caja. En el panel se mantiene el nombre «Cobro de remesa» para los movimientos viejos. |
| 2026-10-13 | iOS pasará de **TestFlight a la App Store** más adelante. Mientras tanto se sigue con TestFlight. | Decisión del usuario. Lo que hoy apunta a TestFlight (respaldo de «Actualizar», `downloadUrl` de iOS, guía del Mac) se cambia entonces; está en el roadmap. |
| 2026-10-13 | El aviso y el bloqueo de versión muestran siempre un botón «Actualizar». Abre el `downloadUrl` del backend y, si no lo hay, la ficha de Ottos en Play Store (Android) o la app TestFlight (iPhone, `itms-beta://`). | Petición del usuario: un botón en vez del enlace o del «pide el enlace a la oficina». Las tiendas son el canal decidido, así que el repartidor nunca se queda sin forma de actualizar. |
| 2026-10-13 | «Elegir de contactos» usa el **selector del sistema** (`flutter_native_contact_picker`: `ACTION_PICK` en Android, `CNContactPickerViewController` en iOS), no la lectura de la agenda. Solo la app lo ofrece; el panel no tiene agenda. | No hay que pedir permiso de contactos ni declarar su uso en Play Store o App Store, y la app nunca ve más que el contacto elegido. El buscador lo trae el propio selector. |
| 2026-10-13 | Android se distribuye por **Google Play**; el `downloadUrl` del aviso de versión será `https://play.google.com/store/apps/details?id=com.remesadeotto.ottos`. iOS, por TestFlight. Pendiente: crear la cuenta de Play Console y confirmar que los repartidores pueden usar Play en Cuba. | Actualizaciones automáticas y un enlace fijo, en vez de pasar APKs por WhatsApp. **Ojo:** Google Play no está disponible en Cuba; antes de publicar hay que confirmar cómo lo instalarán allí. |
| 2026-10-12 | **Aviso y bloqueo de versiones**: la app envía `X-App-Platform` y `X-App-Build`; avisa si hay versión nueva y bloquea por debajo de la mínima (o con un 426), vaciando antes la cola sin conexión. Las versiones las publica el backend con una migración, con los datos que le pasa el frontend al publicar. | Poder retirar una versión con errores sin depender de que el repartidor actualice por su cuenta. Contrato: `ottos/docs/contracts/app-version.md`. |
| 2026-10-12 | El número de compilación que cuenta es el de `pubspec.yaml` (`+N`). Las APK separadas por ABI informan `abi*1000 + N`; la app usa el resto entre 1000. | Que backend y app comparen el mismo número sea cual sea la APK instalada. |
| 2026-10-12 | iOS se compila y sube a TestFlight desde el Mac del usuario ([ios-en-mac.md](ios-en-mac.md)); el workflow de GitHub Actions queda como alternativa. | El usuario tiene Mac y cuenta de Apple Developer; es más directo. |
| 2026-10-12 | La app se llama **Ottos**, identificador `com.remesadeotto.ottos` en Android e iOS, y apunta a producción (`https://api.remesadeotto.com`). La clave de firma de Android vive fuera del repo (`~/.ottos-release/`). | Una sola app para ventas y repartidores. Sin la clave no se pueden publicar actualizaciones; por eso no se versiona. |
| 2026-10-12 | El panel va en su propio dominio (`panel.remesadeotto.com`, `panel-staging…`) con una imagen Docker (Caddy) que sirve la web y reenvía `/api` al backend. | Mismo origen: sin CORS ni `OTTOS_API_URL` por entorno; la misma imagen sirve staging y producción. |
| 2026-10-12 | El panel lleva su fuente Roboto dentro y no pide nada a Google al abrirse. | Los servicios de Google pueden estar bloqueados desde Cuba. |
| 2026-10-11 | Notificaciones **locales** (la app consulta al servidor al abrirse, al volver la red y cada 2 minutos), sin Firebase/FCM. | FCM depende de Google, que puede estar bloqueado desde Cuba. Contrapartida: con la app cerrada no hay avisos. |

## Proceso

| Fecha | Decisión | Por qué |
| --- | --- | --- |
| 2026-10-13 | Un canvas oficial por cliente en Claude Design («Ottos · Panel web» y «Ottos · App móvil»), igual que las vistas reales; cada cambio visual lo actualiza en la misma rama. Otros canvas solo para decidir entre variantes, y se borran al decidir. | Petición del usuario: que el diseño sirva de referencia fiable y no se acumulen canvas viejos. |
| 2026-10-13 | Esperar antes de cerrar `1.0.0-rc.3` por si entran más cambios. | Petición del usuario. |
| 2026-10-12 | Siguiente versión tras rc.2: rc.3 (o `1.0.0` si no aparece nada más). Los tags publicados no se tocan. | Mismo criterio que el backend. |
| 2026-10-12 | Las pruebas contra staging y producción se hacen por API con scripts, nunca escribiendo contraseñas reales en un navegador o emulador. Producción solo tiene el admin del usuario y bloquea 15 min tras 5 fallos. | Seguridad: no exponer credenciales remotas ni bloquear la cuenta del dueño. |
| 2026-10-11 | Prueba general de 1.0 documentada en Claude Docs («Prueba general de Ottos 1.0») y ejecutada por el agente. | Tener una lista repetible de todos los flujos antes de producción. |
| 2026-10-10 | Git Flow, Conventional Commits y Keep a Changelog, igual que el backend ([STANDARDS.md](../STANDARDS.md)). | Petición del usuario: el mismo estándar en los dos repos. |
| 2026-10-10 | Los contratos entre frontend y backend se escriben en el repo del backend (`ottos/docs/contracts/`) y se cierran entre los dos agentes antes de implementar. El frontend no configura Railway: lo de infraestructura va al agente de infraestructura. | Un único sitio para cada contrato y responsabilidades claras entre los tres agentes. |
