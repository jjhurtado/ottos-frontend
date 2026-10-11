import 'package:ottos_core/ottos_core.dart';

/// User-facing texts of the operations panel.
abstract final class OpsTexts {
  static const appName = 'Panel de operaciones';
  static const appTitle = "Otto's · Operaciones";

  // Menu
  static const home = 'Inicio';
  static const remittances = 'Remesas';
  static const customers = 'Clientes';
  static const configuration = 'Configuración';
  static const cash = 'Caja';
  static const users = 'Usuarios';
  static const roles = 'Roles y permisos';
  static const audit = 'Auditoría';
  static const reports = 'Reportes';

  // Home
  static String greeting(String name) => 'Hola, $name';
  static const homeSubtitle = 'Resumen de las remesas abiertas';
  static const lateRemittances = 'Atrasadas';
  static const incidentRemittances = 'Con incidencia';
  static const reviewRemittances = CoreTexts.toReview;
  static const viewAll = 'Ver remesas';

  // Remittance list
  static const searchByCode = 'Buscar por código';
  static const allStatuses = 'Todos los estados';
  static const allTypes = 'Todos los tipos';
  static const onlyLate = 'Solo atrasadas';
  static const onlyIncidents = 'Con incidencia';
  static const onlyToReview = CoreTexts.toReview;
  static const clearFilters = 'Quitar filtros';
  static const noRemittances = 'No hay remesas con estos filtros.';
  static const code = 'Código';
  static const type = 'Tipo';
  static const status = 'Estado';
  static const customer = 'Remitente';
  static const beneficiary = 'Beneficiario';
  static const municipality = 'Municipio';
  static const amount = 'Monto';
  static const expectedDate = 'Fecha prevista';
  static const courier = CoreTexts.courier;
  static String pageOf(int from, int to, int total) => '$from–$to de $total';
  static const previousPage = 'Página anterior';
  static const nextPage = 'Página siguiente';

  // Remittance detail
  static const remittance = 'Remesa';
  static const summary = 'Resumen';
  static const money = 'Importes';
  static const history = 'Historial';
  static const phone = 'Teléfono';
  static const alternatePhone = 'Teléfono alternativo';
  static const address = 'Dirección';
  static const reference = 'Referencia';
  static const fee = 'Comisión';
  static const total = 'Total cobrado';
  static const rate = 'Tasa';
  static const amountToDeliver = 'A entregar';
  static const cashToCollect = 'Efectivo a recoger';
  static const pin = 'PIN';
  static const postponements = 'Aplazamientos';
  static const notes = 'Notas';
  static const createdAt = 'Registrada';
  static const completedAt = 'Completada';
  static const noCourier = 'Sin asignar';
  static const noHistory = 'Sin eventos.';

  // New remittance
  static const newRemittance = 'Nueva remesa';
  static const searchCustomer = 'Nombre o teléfono';
  static const changeCustomer = 'Cambiar remitente';
  static const chooseCustomerFirst = 'Elige primero el remitente';
  static const noBeneficiaries = 'Este remitente no tiene beneficiarios todavía. Búscalo entre todos o crea uno.';
  static const amountToSend = 'Monto a enviar';
  static const targetCurrency = 'Moneda a entregar';
  static const noRates = 'No hay tasas de cambio configuradas; no se pueden registrar remesas.';
  static const quoteHint = 'Escribe el monto para ver la comisión y lo que se entrega.';
  static const notesOptional = 'Notas (opcional)';
  static const register = 'Registrar remesa';
  static String remittanceRegistered(String code) => 'Remesa $code registrada';

  // Remittance actions
  static const assignCourier = CoreTexts.assignCourier;
  static const reassignCourier = CoreTexts.reassignCourier;
  static const assign = CoreTexts.assign;
  static const noCouriers = CoreTexts.noCouriers;
  static String openRemittances(int count) => CoreTexts.openRemittances(count);
  static const markDelivered = 'Marcar como entregada';
  static const markCollected = 'Marcar como recogida';
  static const assigned = 'Repartidor asignado';
  static const completed = 'Remesa completada';
  static const postponed = 'Remesa aplazada';
  static const resolve = 'Resolver';
  static const resolveReviewTitle = 'Resolver revisión';
  static const resolveReviewHelp = 'Cuenta qué comprobaste; la nota queda en el historial.';
  static const resolveNote = 'Nota *';
  static const reviewResolved = 'Revisión resuelta';

  static String eventTitle(String type) => switch (type) {
    'CREATED' => 'Remesa registrada',
    'STATUS_CHANGED' => 'Cambio de estado',
    'POSTPONED' => 'Aplazada',
    'INCIDENT_REPORTED' => CoreTexts.incidentReported,
    'REVIEW_FLAGGED' => 'Marcada para revisión',
    'REVIEW_RESOLVED' => 'Revisión resuelta',
    _ => type,
  };

  // Customers
  static const newCustomer = 'Nuevo cliente';
  static const editCustomer = 'Editar cliente';
  static const customerData = 'Datos';
  static const fullName = 'Nombre completo';
  static const email = 'Correo electrónico';
  static const document = 'Documento';
  static const documentType = 'Tipo de documento';
  static const documentNumber = 'Número de documento';
  static const inactive = 'Inactivo';
  static const noCustomers = 'Ningún cliente coincide con la búsqueda.';
  static const noCustomersYet = 'Todavía no hay clientes.';
  static const edit = 'Editar';
  static const save = 'Guardar';
  static const requiredField = 'Obligatorio';
  static const phoneInvalid = 'Teléfono no válido';
  static const viewRemittances = 'Ver remesas';
  static const totalRemittances = 'Remesas';
  static const openRemittancesLabel = 'Abiertas';
  static const amountSent = 'Total enviado';
  static const totalCharged = 'Total cobrado';
  static const amountCollected = 'Total recogido';
  static const lastRemittance = 'Última remesa';

  // Beneficiaries
  static const beneficiaries = 'Beneficiarios';
  static const newBeneficiary = 'Nuevo beneficiario';
  static const editBeneficiary = 'Editar beneficiario';
  static const street = 'Calle';
  static const houseNumber = 'Número';
  static const betweenStreets = 'Entre calles';
  static const neighborhood = 'Reparto';
  static const province = 'Provincia';
  static const unlink = 'Desvincular';
  static const unlinkTitle = 'Desvincular beneficiario';
  static String unlinkMessage(String name) =>
      '$name dejará de aparecer como beneficiario de este cliente. Las remesas anteriores no cambian.';

  // Cash
  static const businessCash = 'Caja del negocio';
  static const couriersCash = 'Efectivo de los repartidores';
  static const latestMovements = 'Últimos movimientos';
  static const cashMovements = 'Movimientos de caja';
  static const balance = 'Saldo';
  static const currency = 'Moneda';
  static const amountRequired = 'Escribe un monto mayor que 0';
  static const noBalances = 'Sin saldo todavía.';
  static const noCourierCash = 'Ningún repartidor tiene movimientos de caja.';
  static const noMovements = 'Sin movimientos.';
  static const courierOwes = 'Debe efectivo al negocio en alguna moneda.';
  static const deposit = 'Depositar';
  static const withdraw = 'Retirar';
  static const depositHelp = 'Dinero que entra a la caja desde fuera: capital, CUP comprados…';
  static const withdrawHelp = 'Dinero que sale de la caja: gastos, USD vendidos…';
  static const fund = 'Entregar fondos';
  static const registerReturn = 'Registrar devolución';
  static String fundCourierTitle(String name) => 'Entregar fondos a $name';
  static String courierReturnTitle(String name) => 'Devolución de $name';
  static String movementRegistered(String amount) => 'Movimiento de $amount registrado';

  /// Movement names from the business's point of view.
  static String movementTitle(CashMovementType type) => switch (type) {
    CashMovementType.remittancePayment => 'Cobro de remesa',
    CashMovementType.courierFunding => 'Fondos a repartidor',
    CashMovementType.deliveryPayout => 'Entrega de remesa',
    CashMovementType.pickupCollection => 'Recogida de remesa',
    CashMovementType.courierReturn => 'Devolución de repartidor',
    CashMovementType.courierSurplus => 'Sobrante de repartidor',
    CashMovementType.remittanceRefund => 'Reembolso de remesa',
    CashMovementType.businessDeposit => 'Depósito',
    CashMovementType.businessWithdrawal => 'Retiro',
    CashMovementType.courierExchangeOut => 'Cambio de moneda: entregado',
    CashMovementType.courierExchangeIn => 'Cambio de moneda: recibido',
    CashMovementType.unknown => 'Movimiento',
  };

  // Configuration
  static const generalSettings = 'Ajustes generales';
  static const minimumAmount = 'Monto mínimo por remesa';
  static const minimumAmountHint = '0 = sin mínimo';
  static const noMinimum = 'Sin mínimo';
  static const deliveryDays = 'Días para entregar';
  static String deliveryDaysValue(int days) =>
      days == 1 ? '1 día desde que se registra' : '$days días desde que se registra';
  static const deliveryDaysHint = 'Fecha prevista de las remesas nuevas: entre 1 y 60 días';
  static const deliveryDaysRange = 'Entre 1 y 60';
  static const settingsSaved = 'Ajustes guardados';

  // Rates
  static const calculator = 'Calculadora';
  static const calculate = 'Calcular';
  static const newRate = 'Nueva tasa';
  static const newFeeRule = 'Nueva comisión';
  static String ratesFor(RemittanceType type) => switch (type) {
    RemittanceType.delivery => 'Entregas',
    RemittanceType.pickup => 'Recogidas',
  };
  static String _ofType(RemittanceType type) => switch (type) {
    RemittanceType.delivery => 'de entrega',
    RemittanceType.pickup => 'de recogida',
  };
  static String newRateTitle(String corridor, RemittanceType type) => 'Nueva tasa ${_ofType(type)} $corridor';
  static String newRateHelp(String source, String target) =>
      'Cuántos $target se entregan por cada $source. Se aplica a las remesas que se registren desde ahora.';
  static String newFeeRuleTitle(String corridor, RemittanceType type) => 'Nueva comisión ${_ofType(type)} $corridor';
  static const newFeeRuleHelp = 'Se aplica a las remesas que se registren desde ahora; las anteriores no cambian.';
  static const feePercentage = 'Porcentaje';
  static const feeFixed = 'Fija';
  static const feeValue = 'Valor';
  static const minFee = 'Mínimo';
  static const maxFee = 'Máximo';
  static const fixedRate = '1 (misma moneda)';
  static const noRate = 'Sin tasa';
  static const noFeeRule = 'Sin comisión configurada';
  static String noRateWarning(RemittanceType type) => switch (type) {
    RemittanceType.delivery => 'Sin tasa no se pueden registrar entregas en esta moneda.',
    RemittanceType.pickup => 'Sin tasa no se pueden registrar recogidas en esta moneda.',
  };
  static const rounding = 'Redondeo';
  static String roundingValue(String step) => 'A entregar se redondea hacia abajo a múltiplos de $step';
  static const rateSaved = 'Tasa guardada';
  static const feeRuleSaved = 'Comisión guardada';
  static const rateHistory = 'Tasas anteriores';
  static const feeHistory = 'Comisiones anteriores';

  /// `410 CUP por 1 USD, desde 9 oct 2026 14:32`.
  static String rateValue(double rate, Corridor corridor, DateTime? since) {
    final value = '${Formatters.money(rate, corridor.targetCurrency)} por 1 ${corridor.sourceCurrency}';
    return since == null ? value : '$value, desde ${Formatters.dateTime(since)}';
  }

  /// `10 % (mínimo 10,00 USD)` or `5,00 USD`.
  static String describeFee(FeeRule rule, String currency) {
    final base = rule.type == FeeType.percentage
        ? '${Formatters.money(rule.value, null)} %'
        : Formatters.money(rule.value, currency);
    final bounds = [
      if (rule.minFee != null && rule.minFee! > 0) 'mínimo ${Formatters.money(rule.minFee, currency)}',
      if (rule.maxFee != null) 'máximo ${Formatters.money(rule.maxFee, currency)}',
    ];
    return bounds.isEmpty ? base : '$base (${bounds.join(', ')})';
  }

  // Users
  static const newUser = 'Nuevo usuario';
  static const editUser = 'Editar usuario';
  static const searchUser = 'Nombre, correo o rol';
  static String showInactive(int count) => 'Mostrar inactivos ($count)';
  static const noUsers = 'Ningún usuario coincide.';
  static const userRoles = 'Roles';
  static const chooseRole = 'Elige al menos un rol';
  static const initialPassword = 'Contraseña inicial';
  static const active = 'Activo';
  static const you = 'tú';
  static const actions = 'Acciones';
  static const resetPassword = 'Restablecer contraseña';
  static String resetPasswordTitle(String name) => 'Contraseña de $name';
  static const resetPasswordHelp = 'Se cerrarán sus sesiones abiertas; tendrá que entrar con la contraseña nueva.';
  static const deactivate = 'Desactivar';
  static const activate = 'Activar';
  static const deactivateTitle = 'Desactivar usuario';
  static String deactivateMessage(String name) =>
      '$name no podrá entrar y se cerrarán sus sesiones. Sus datos y remesas no cambian; puedes reactivarlo cuando quieras.';
  static String userCreated(String name) => 'Usuario $name creado';
  static const userSaved = 'Usuario guardado';
  static const passwordReset = 'Contraseña restablecida';
  static const userDeactivated = 'Usuario desactivado';
  static const userActivated = 'Usuario activado';

  // Roles
  static const newRole = 'Nuevo rol';
  static String editRole(String name) => 'Editar rol $name';
  static const roleCode = 'Código';
  static const roleCodeHint = 'Mayúsculas y guiones bajos, p. ej. SUPERVISOR; no se puede cambiar';
  static const roleCodeInvalid = 'Solo mayúsculas, números y guiones bajos; empieza por una letra (2 a 50)';
  static const roleName = 'Nombre';
  static const roleDescription = 'Descripción';
  static const permissions = 'Permisos';
  static const onlyYourPermissions = 'Solo puedes dar o quitar permisos que tú tienes.';
  static const builtIn = 'Del sistema';
  static const delete = 'Eliminar';
  static String permissionCount(int count) => count == 1 ? '1 permiso' : '$count permisos';
  static const deleteRoleTitle = 'Eliminar rol';
  static String deleteRoleMessage(String name) =>
      'El rol $name se eliminará. Solo se puede si ningún usuario lo tiene.';
  static String roleCreated(String name) => 'Rol $name creado';
  static const roleSaved = 'Rol guardado';
  static const roleDeleted = 'Rol eliminado';

  static String permissionModule(String module) => switch (module) {
    'remittances' => 'Remesas',
    'customers' => 'Clientes y beneficiarios',
    'payments' => 'Caja',
    'configuration' => 'Configuración',
    'rates' => 'Cotizaciones',
    'identity' => 'Usuarios y roles',
    '' => 'Otros',
    _ => module,
  };

  /// What a permission allows, in Spanish; the backend's English description otherwise.
  static String permissionLabel(PermissionInfo permission) => switch (permission.code) {
    Permissions.remittancesCreate => 'Registrar remesas',
    Permissions.remittancesRead => 'Ver todas las remesas y su historial',
    Permissions.remittancesReadAssigned => 'Ver sus remesas asignadas (repartidor)',
    Permissions.remittancesReadFinancials => 'Ver importes de las recogidas',
    Permissions.remittancesAssign => 'Asignar y reasignar repartidores',
    Permissions.remittancesDeliver => 'Marcar como entregada o recogida (repartidor)',
    Permissions.remittancesPostpone => 'Aplazar remesas',
    Permissions.remittancesReportIncident => 'Reportar incidencias de entrega (repartidor)',
    Permissions.remittancesReview => 'Revisar remesas marcadas (entregas sin conexión)',
    Permissions.auditRead => 'Ver el registro de auditoría',
    Permissions.reportsRead => 'Ver los reportes del negocio (resumen mensual)',
    Permissions.cashExchangeOwn => 'Cambiar moneda en su propia caja (repartidor)',
    Permissions.cashReview => 'Revisar cambios de moneda marcados',
    Permissions.customersExport => 'Exportar clientes y beneficiarios (CSV)',
    Permissions.customersImport => 'Importar clientes y beneficiarios (CSV)',
    Permissions.customersRead => 'Ver clientes y beneficiarios',
    Permissions.customersWrite => 'Crear y editar clientes y beneficiarios',
    Permissions.cashRead => 'Ver la caja del negocio y de los repartidores',
    Permissions.cashReadOwn => 'Ver su propia caja (repartidor)',
    Permissions.cashWrite => 'Entregar fondos y registrar devoluciones de repartidores',
    Permissions.cashAdjust => 'Depositar y retirar de la caja del negocio',
    Permissions.configurationRead => 'Ver la configuración, tasas y comisiones',
    Permissions.configurationWrite => 'Cambiar la configuración, tasas y comisiones',
    Permissions.ratesRead => 'Calcular cotizaciones',
    Permissions.usersRead => 'Ver usuarios',
    Permissions.usersWrite => 'Crear, editar, activar y desactivar usuarios',
    Permissions.rolesRead => 'Ver roles y permisos',
    Permissions.rolesWrite => 'Crear, editar y eliminar roles',
    _ => permission.description ?? permission.code,
  };

  // Audit log
  static const auditSubtitle = 'Quién cambió usuarios y roles, y cuándo.';
  static const allTargets = 'Todo';
  static const allActions = 'Todas las acciones';
  static const action = 'Acción';
  static const who = 'Quién';
  static const target = 'Sobre';
  static const detail = 'Detalle';
  static const when = 'Fecha';
  static const fromDate = 'Desde';
  static const toDate = 'Hasta';
  static const system = 'El sistema';
  static const noAuditEntries = 'No hay cambios registrados con estos filtros.';

  static String auditTarget(String type) => switch (type) {
    'USER' => 'Usuarios',
    'ROLE' => 'Roles',
    _ => type,
  };

  /// The actions of the audit log, by their stable code.
  static const auditActions = {
    'USER': [
      'USER_CREATED',
      'USER_RENAMED',
      'USER_ROLES_CHANGED',
      'USER_DEACTIVATED',
      'USER_ACTIVATED',
      'USER_PASSWORD_RESET',
      'PASSWORD_CHANGED',
    ],
    'ROLE': ['ROLE_CREATED', 'ROLE_DESCRIBED', 'ROLE_PERMISSIONS_CHANGED', 'ROLE_DELETED'],
  };

  static String auditAction(String code) => switch (code) {
    'USER_CREATED' => 'Usuario creado',
    'USER_RENAMED' => 'Nombre cambiado',
    'USER_ROLES_CHANGED' => 'Roles cambiados',
    'USER_DEACTIVATED' => 'Usuario desactivado',
    'USER_ACTIVATED' => 'Usuario reactivado',
    'USER_PASSWORD_RESET' => 'Contraseña restablecida',
    'PASSWORD_CHANGED' => 'Cambió su contraseña',
    'ROLE_CREATED' => 'Rol creado',
    'ROLE_DESCRIBED' => 'Nombre o descripción del rol cambiados',
    'ROLE_PERMISSIONS_CHANGED' => 'Permisos cambiados',
    'ROLE_DELETED' => 'Rol eliminado',
    _ => code,
  };

  /// What changed, in Spanish lines: roles and permissions by their names.
  static List<String> auditDetails(AuditEntry entry) {
    final details = entry.details;
    List<String> codes(Object? value) => [for (final item in value as List? ?? const []) '$item'];
    String roles(Object? value) => codes(value).map(CoreTexts.roleCode).join(', ');
    String permissions(Object? value) =>
        codes(value).map((code) => permissionLabel(PermissionInfo(code: code, module: ''))).join('; ');
    String text(Object? value) => value == null || '$value'.isEmpty ? '—' : '$value';
    Map<String, dynamic> map(Object? value) => (value as Map<String, dynamic>?) ?? const {};
    return switch (entry.action) {
      'USER_CREATED' => [
        if (details['name'] != null) 'Nombre: ${details['name']}',
        if (details['roles'] != null) 'Roles: ${roles(details['roles'])}',
        if (details['reason'] != null) 'Motivo: ${details['reason']}',
      ],
      'USER_RENAMED' => ['${text(details['before'])} → ${text(details['after'])}'],
      'USER_ROLES_CHANGED' => ['${roles(details['before'])} → ${roles(details['after'])}'],
      'ROLE_CREATED' => [
        if (details['name'] != null) 'Nombre: ${details['name']}',
        if (details['description'] != null) 'Descripción: ${details['description']}',
        if (details['permissions'] != null) 'Permisos: ${permissions(details['permissions'])}',
      ],
      'ROLE_DESCRIBED' => [
        if (map(details['before'])['name'] != map(details['after'])['name'])
          'Nombre: ${text(map(details['before'])['name'])} → ${text(map(details['after'])['name'])}',
        if (map(details['before'])['description'] != map(details['after'])['description'])
          'Descripción: ${text(map(details['before'])['description'])} → '
              '${text(map(details['after'])['description'])}',
      ],
      'ROLE_PERMISSIONS_CHANGED' => [
        if (codes(details['added']).isNotEmpty) 'Añadidos: ${permissions(details['added'])}',
        if (codes(details['removed']).isNotEmpty) 'Quitados: ${permissions(details['removed'])}',
      ],
      'ROLE_DELETED' => [
        if (details['name'] != null) 'Nombre: ${details['name']}',
        if (details['permissions'] != null) 'Tenía: ${permissions(details['permissions'])}',
      ],
      _ => [for (final entry in details.entries) '${entry.key}: ${entry.value}'],
    };
  }

  // Monthly report
  static const monthlyReport = 'Resumen mensual';
  static const exportPdf = 'Exportar PDF';
  static const previousMonth = 'Mes anterior';
  static const nextMonth = 'Mes siguiente';
  static const reportRemittances = 'Remesas';
  static const totalCollected = 'Total cobrado';
  static const totalCollectedHelp = 'Monto enviado + comisión, pagado por los remitentes';
  static const totalDelivered = 'Total entregado';
  static const difference = 'Diferencia';
  static const differenceHelp = 'Cobrado − entregado';
  static const earnings = 'Ganancias (comisiones)';
  static const byCurrency = 'Por moneda de entrega';
  static const byType = 'Por tipo';
  static const monthEndStatus = 'Estado al cierre del mes';
  static const sent = 'Enviado';
  static const fees = 'Comisiones';
  static const collected = 'Cobrado';
  static const delivered = 'Entregado';
  static const deliveredUsd = 'Entregado en USD';
  static const completedLabel = 'Completadas';
  static const openLabel = 'Abiertas (pagadas o asignadas)';
  static const withIncidentLabel = 'Con incidencia';
  static const totalRow = 'Total';
  static const noSales = 'No hay remesas registradas este mes.';
  static String deliveriesAndPickups(int deliveries, int pickups) => '$deliveries entregas · $pickups recogidas';
  static String roundingNote(String amount) => '+$amount por redondeo al entregar';
  static String reportPeriod(String from, String to) => 'Del $from al $to · hora de Cuba · importes en USD';
  static String generatedOn(String when) => 'Generado el $when';
  static String reportFileName(String month) => 'resumen-mensual-$month.pdf';

  // Currency exchanges
  static const registerExchange = 'Registrar cambio';
  static String exchangeForTitle(String name) => 'Cambio de moneda de $name';
  static const exchangeRegistered = 'Cambio registrado';
  static const exchangeFlagged = 'Cambio registrado y marcado para revisar: la tasa se aleja de la configurada.';
  static const exchangesToReview = 'Cambios de moneda para revisar';
  static const exchangeReviewResolved = 'Revisión del cambio resuelta';
  static String exchangeLine(String from, String to) => '$from → $to';
  static String exchangeRates(String rate, String? configured, String? deviation) => configured == null
      ? 'Tasa $rate CUP/USD'
      : 'Tasa $rate CUP/USD · configurada $configured · se aleja $deviation %';
  static const exchangeTolerance = 'Tolerancia de la tasa de cambio';
  static const exchangeToleranceHint =
      'Un cambio de un repartidor que se aleje más de esto de la tasa de entrega se marca para revisar.';
  static String exchangeToleranceValue(String percent) => '$percent %';
  static const exchangeToleranceRange = 'Entre 0 y 1000';

  // Customers CSV
  static const exportCsv = 'Exportar CSV';
  static const importCsv = 'Importar CSV';
  static const importPreview = 'Vista previa de la importación';
  static const importPreviewHelp = 'Todavía no se ha guardado nada. Lo que ya existe se vincula, nunca se cambia.';
  static const importDone = 'Importación hecha';
  static const importConfirm = 'Importar';
  static const importEmpty = 'El archivo no tiene clientes.';
  static const importLinks = 'Vínculos nuevos';
  static const importBeneficiariesCsv = 'Importar beneficiarios';
  static const importNoBeneficiaries = 'El archivo no tiene beneficiarios.';
  static const importBeneficiariesHelp =
      'Se cargan sin remitente: cada uno queda vinculado a su cliente con la primera remesa que se le envíe.';
  static const importRejected = 'Rechazados';
  static const close = 'Cerrar';
  static String importCounts(int created, int existing, int rejected) =>
      '$created nuevos · $existing ya existían · $rejected rechazados';
  static String customersFileName(String date) => 'clientes-$date.csv';
}
