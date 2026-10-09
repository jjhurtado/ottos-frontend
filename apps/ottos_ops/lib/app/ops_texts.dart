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

  static String eventTitle(String type) => switch (type) {
    'CREATED' => 'Remesa registrada',
    'STATUS_CHANGED' => 'Cambio de estado',
    'POSTPONED' => 'Aplazada',
    _ => type,
  };

  // Coming soon
  static const comingSoon = 'Esta sección estará disponible pronto.';
}
