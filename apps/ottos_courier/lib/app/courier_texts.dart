/// User-facing texts of the courier app.
abstract final class CourierTexts {
  static const appName = 'App de repartidores';
  static const appTitle = "Otto's · Repartidor";

  // Navigation
  static const account = 'Mi cuenta';
  static const myRemittances = 'Mis remesas';
  static const myCash = 'Mi caja';
  static const cash = 'Caja';

  static const remittances = 'Remesas';

  // New remittance
  static const newRemittance = 'Nueva remesa';
  static const customer = 'Remitente';
  static const searchCustomer = 'Busca por nombre o teléfono';
  static const changeCustomer = 'Cambiar remitente';
  static const chooseCustomerFirst = 'Elige primero el remitente';
  static const noBeneficiaries = 'Este remitente no tiene beneficiarios. Dalos de alta en el panel.';
  static const amountToSend = 'Monto a enviar';
  static const targetCurrency = 'Moneda';
  static const noRates = 'No hay monedas con tasa para este tipo de remesa.';
  static const quoteHint = 'Escribe el monto para ver la comisión y lo que se entrega.';
  static const fee = 'Comisión';
  static const total = 'Total a cobrar';
  static const rate = 'Tasa';
  static const amountToDeliver = 'Se entrega';
  static const cashToCollect = 'Se recoge';
  static const courier = 'Repartidor';
  static const noCourier = 'Sin asignar';
  static const notesOptional = 'Notas (opcional)';
  static const register = 'Registrar';
  static String registered(String code) => 'Remesa $code registrada';

  // Cash of the couriers
  static const couriersCash = 'Efectivo de los repartidores';
  static const noCouriers = 'No hay repartidores con efectivo.';
  static const fund = 'Entregar fondos';
  static const registerReturn = 'Registrar devolución';
  static String fundTitle(String name) => 'Entregar fondos a $name';
  static String returnTitle(String name) => 'Devolución de $name';
  static String movementRegistered(String amount) => 'Movimiento de $amount registrado';

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
  static const assignToCourier = 'Asignar a repartidor';
  static const assigned = 'Repartidor asignado';

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
