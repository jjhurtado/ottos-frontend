/// User-facing texts of the courier app.
abstract final class CourierTexts {
  static const appName = 'App de repartidores';
  static const appTitle = "Otto's · Repartidor";

  // Navigation
  static const account = 'Mi cuenta';
  static const myRemittances = 'Mis remesas';
  static const myCash = 'Mi caja';

  // Assigned list
  static const noAssigned = 'No tienes remesas pendientes.';
  static const toDeliver = 'Entregar';
  static const toCollect = 'Recoger';
  static String dueOn(String date) => 'Para el $date';
  static String daysLate(int days) => days == 1 ? '1 día de atraso' : '$days días de atraso';
  static const sortByDay = 'Del día';
  static const sortMostLate = 'Más atrasadas primero';

  // Remittance
  static const beneficiary = 'Beneficiario';
  static const phone = 'Teléfono';
  static const alternatePhone = 'Teléfono alternativo';
  static const address = 'Dirección';
  static const municipality = 'Municipio';
  static const reference = 'Referencia';
  static const sender = 'Remitente';
  static const expectedDate = 'Fecha prevista';
  static const notes = 'Notas';
  static const call = 'Llamar';
  static const whatsApp = 'Escribir por WhatsApp';
  static const markDelivered = 'Marcar como entregada';
  static const markCollected = 'Marcar como recogida';
  static const completed = 'Remesa completada';
  static const postponed = 'Remesa aplazada';

  // Cash
  static const balances = 'Saldo en mano';
  static const owesBusiness = 'Debes efectivo al negocio en alguna moneda.';
  static const movements = 'Movimientos';
  static const noMovements = 'Todavía no tienes movimientos.';

  static String movementTitle(String type) => switch (type) {
    'COURIER_FUNDING' => 'Fondos recibidos',
    'DELIVERY_PAYOUT' => 'Entrega de remesa',
    'PICKUP_COLLECTION' => 'Recogida de remesa',
    'COURIER_RETURN' => 'Devolución al negocio',
    'COURIER_SURPLUS' => 'Sobrante en cierre',
    _ => 'Movimiento',
  };
}
