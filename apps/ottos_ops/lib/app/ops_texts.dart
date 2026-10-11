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

  // Home
  static String greeting(String name) => 'Hola, $name';
  static const homeSubtitle = 'Resumen de las remesas abiertas';
  static const lateRemittances = 'Atrasadas';
  static const incidentRemittances = 'Con incidencia';
  static const viewAll = 'Ver remesas';

  // Remittance list
  static const searchByCode = 'Buscar por código';
  static const allStatuses = 'Todos los estados';
  static const allTypes = 'Todos los tipos';
  static const onlyLate = 'Solo atrasadas';
  static const onlyIncidents = 'Con incidencia';
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
  static const noBeneficiaries = 'Este remitente no tiene beneficiarios todavía.';
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

  static String eventTitle(String type) => switch (type) {
    'CREATED' => 'Remesa registrada',
    'STATUS_CHANGED' => 'Cambio de estado',
    'POSTPONED' => 'Aplazada',
    'INCIDENT_REPORTED' => CoreTexts.incidentReported,
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
}
