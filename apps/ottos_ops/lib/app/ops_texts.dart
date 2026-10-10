/// User-facing texts of the operations panel.
abstract final class OpsTexts {
  static const appName = 'Panel de operaciones';
  static const appTitle = "Otto's · Operaciones";

  // Menu
  static const home = 'Inicio';
  static const remittances = 'Remesas';
  static const customers = 'Clientes';
  static const rates = 'Tasas y comisiones';
  static const cash = 'Caja';
  static const users = 'Usuarios';
  static const roles = 'Roles y permisos';

  // Home
  static String greeting(String name) => 'Hola, $name';
  static const homeSubtitle = 'Resumen de las remesas abiertas';
  static const lateRemittances = 'Atrasadas';
  static const viewAll = 'Ver remesas';

  // Remittance list
  static const searchByCode = 'Buscar por código';
  static const allStatuses = 'Todos los estados';
  static const allTypes = 'Todos los tipos';
  static const onlyLate = 'Solo atrasadas';
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
  static const courier = 'Repartidor';
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
  static const assignCourier = 'Asignar repartidor';
  static const reassignCourier = 'Reasignar repartidor';
  static const assign = 'Asignar';
  static const noCouriers = 'No hay repartidores disponibles.';
  static String openRemittances(int count) => count == 1 ? '1 remesa abierta' : '$count remesas abiertas';
  static const markDelivered = 'Marcar como entregada';
  static const markCollected = 'Marcar como recogida';
  static const assigned = 'Repartidor asignado';
  static const completed = 'Remesa completada';
  static const postponed = 'Remesa aplazada';

  static String eventTitle(String type) => switch (type) {
    'CREATED' => 'Remesa registrada',
    'STATUS_CHANGED' => 'Cambio de estado',
    'POSTPONED' => 'Aplazada',
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

  // Coming soon
  static const comingSoon = 'Esta sección estará disponible pronto.';
}
