import 'package:ottos_core/ottos_core.dart';

import '../offline/sync_cubit.dart';

/// User-facing texts of the courier app.
abstract final class CourierTexts {
  static const appName = 'App de repartidores';
  static const appTitle = 'Ottos';

  // Notifications
  static const newRemittancesChannel = 'Remesas nuevas';
  static const newRemittancesChannelHelp = 'Remesas que te asignan';
  static const completedChannel = 'Remesas completadas';
  static const completedChannelHelp = 'Entregas y recogidas que terminan los repartidores';
  static String newRemittanceTitle(Remittance remittance) =>
      remittance.isPickup ? 'Nueva recogida asignada' : 'Nueva entrega asignada';
  static String newRemittancesTitle(int count) => 'Tienes $count remesas nuevas';
  static String completedTitle(Remittance remittance) =>
      remittance.isPickup ? 'Recogida completada' : 'Remesa entregada';
  static String completedManyTitle(int count) => '$count remesas completadas';
  static const tapToSee = 'Toca para verlas';

  // Navigation
  static const account = 'Mi cuenta';
  static String version(String version) => 'Ottos versión $version';
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
  static const noBeneficiaries = 'Este remitente no tiene beneficiarios todavía. Búscalo entre todos o crea uno.';
  static const newCustomer = 'Nuevo remitente';
  static const newBeneficiary = 'Nuevo beneficiario';
  static const amountToSend = 'Monto a enviar';
  static const amountToCollect = 'Monto a recoger';
  static const targetCurrency = 'Moneda';
  static const noRates = 'No hay monedas con tasa para este tipo de remesa.';
  static const quoteHint = 'Escribe el monto para ver la comisión y lo que se entrega.';
  static const pickupQuoteHint = 'Escribe el monto para ver la comisión.';
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

  // Offline
  static const unsent = 'Sin enviar';
  static const queued = 'Guardada en el teléfono. Se enviará cuando haya conexión.';
  static const flagged = 'Hecho. Queda marcada para que ventas la revise.';
  static const exchangeDone = 'Cambio registrado';
  static const exchangeFlagged = 'Cambio registrado. Ventas lo revisará: la tasa se aleja de la configurada.';
  static const syncNow = 'Sincronizar';
  static const dismiss = 'Descartar';
  static const notSyncedTitle = 'No sincronizadas';
  static const notSyncedHelp = 'El servidor no aceptó estas acciones. Revisa la remesa o avisa a ventas.';
  static const nothingRejected = 'No hay acciones rechazadas.';
  static String notSynced(int count) => count == 1 ? '1 acción no sincronizada' : '$count acciones no sincronizadas';
  static String pendingActions(int count) => count == 1 ? '1 sin enviar' : '$count sin enviar';
  static String unsentOnLogout(int count) =>
      'Tienes ${count == 1 ? '1 acción' : '$count acciones'} sin enviar en el teléfono. '
      'Si cierras sesión ahora se perderán. '
      'Conéctate y sincroniza antes de salir.';
  static const logoutAnyway = 'Cerrar sesión igualmente';

  static String actionName(SyncActionType type) => switch (type) {
    SyncActionType.deliver || SyncActionType.deliverWithPin => 'Completar remesa',
    SyncActionType.postpone => 'Aplazar remesa',
    SyncActionType.reportIncident => 'Reportar incidencia',
    SyncActionType.cashExchange => CoreTexts.exchange,
  };

  /// "Sin conexión · 2 sin enviar", "Sincronizado hace 5 min"…
  static String syncSummary(SyncStatus status, {required DateTime now}) {
    final parts = <String>[
      if (status.syncing) 'Sincronizando…' else if (status.offline) 'Sin conexión' else _since(status.lastSync, now),
      if (status.pending > 0) pendingActions(status.pending),
    ];
    return parts.join(' · ');
  }

  static String _since(DateTime? lastSync, DateTime now) {
    if (lastSync == null) return 'Sin sincronizar todavía';
    final minutes = now.difference(lastSync).inMinutes;
    if (minutes < 1) return 'Sincronizado ahora';
    if (minutes < 60) return 'Sincronizado hace $minutes min';
    return 'Sincronizado a las ${Formatters.time(lastSync)}';
  }

  /// What to tell after an action: [done] if it went through.
  static String outcome(ActionOutcome outcome, {required String done}) => switch (outcome) {
    Applied(flaggedForReview: true) => flagged,
    Applied() => done,
    Queued() => queued,
    Rejected(:final message) => message,
  };
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
    'COURIER_EXCHANGE_OUT' => 'Cambio de moneda: entregado',
    'COURIER_EXCHANGE_IN' => 'Cambio de moneda: recibido',
    _ => 'Movimiento',
  };
}
