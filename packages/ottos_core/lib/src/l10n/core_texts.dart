import '../models/remittance.dart';

/// User-facing texts of the shared package. The interface is in Spanish only.
abstract final class CoreTexts {
  // Errors
  static const networkError = 'No se pudo conectar con el servidor. Revisa tu conexión.';
  static const invalidCredentials = 'Correo o contraseña incorrectos.';
  static const sessionExpired = 'Tu sesión expiró. Vuelve a iniciar sesión.';
  static const forbidden = 'No tienes permiso para realizar esta acción.';
  static const notFound = 'No se encontró lo que buscabas.';
  static const invalidRequest = 'Los datos enviados no son válidos.';
  static const unexpectedError = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  static const noAccessToApp = 'Tu usuario no tiene acceso a esta aplicación.';
  static String amountBelowMinimum(String minimum) => 'El monto mínimo es $minimum.';
  static const conflict = 'La operación no se pudo completar en el estado actual. Recarga e inténtalo de nuevo.';

  /// Messages for the backend's error codes (README, "Errors"). Codes are never
  /// renamed; a code missing here falls back to a message by HTTP status.
  static const errorCodes = {
    'INVALID_CREDENTIALS': invalidCredentials,
    'VALIDATION_FAILED': invalidRequest,
    'CONCURRENT_UPDATE': 'Otra persona modificó estos datos a la vez. Inténtalo de nuevo.',
    'AMOUNT_TOO_SMALL': 'El monto es demasiado pequeño: no alcanza para entregar nada.',
    'INVALID_AMOUNT': 'El monto no es válido.',
    'BENEFICIARY_NOT_LINKED': 'El beneficiario no pertenece a este remitente.',
    'BENEFICIARY_UNAVAILABLE': 'El beneficiario no existe o está inactivo.',
    'CUSTOMER_UNAVAILABLE': 'El remitente no existe o está inactivo.',
    'NO_ACTIVE_CORRIDOR': 'No se envía dinero en esa moneda.',
    'NO_EXCHANGE_RATE': 'No hay tasa de cambio configurada para esa moneda.',
    'NO_FEE_RULE': 'No hay comisión configurada para esa moneda.',
    'COURIER_REQUIRED': 'Elige un repartidor.',
    'INVALID_COURIER': 'Ese usuario no puede recibir remesas.',
    'COURIER_NOT_ASSIGNED': 'La remesa no está asignada a ti.',
    'INCORRECT_PIN': 'El PIN no es correcto.',
    'INVALID_OCCURRED_AT': 'La hora de la acción no es válida: es futura, demasiado antigua o anterior a la remesa.',
    'ACTION_ID_CONFLICT': 'Esta acción ya se registró con otros datos.',
    'REVIEW_NOT_PENDING': 'Ya no está pendiente de revisión.',
    'INVALID_CURRENCY': 'Una de las dos monedas tiene que ser USD, y tienen que ser distintas.',
    'INVALID_RATE': 'Escribe una tasa mayor que 0.',
    'EXCHANGE_NOT_FOUND': 'No se encontró ese cambio de moneda.',
    'INVALID_POSTPONE_DATE': 'La nueva fecha debe ser posterior a la fecha prevista.',
    'REMITTANCE_NOT_FOUND': 'No se encontró la remesa.',
    'REMITTANCE_ALREADY_COMPLETED': 'La remesa ya está completada.',
    'REMITTANCE_NOT_ASSIGNABLE': 'La remesa no se puede asignar en su estado actual.',
    'REMITTANCE_NOT_COMPLETABLE': 'La remesa no se puede completar en su estado actual.',
    'TRANSITION_NOT_ALLOWED': 'Ese cambio de estado no está permitido.',
    'TRANSITION_FORBIDDEN': forbidden,
    'CUSTOMER_NOT_FOUND': 'No se encontró el remitente.',
    'BENEFICIARY_NOT_FOUND': 'No se encontró el beneficiario.',
    'CUSTOMER_ALREADY_REGISTERED': 'Ya hay un cliente con ese nombre, teléfono y dirección.',
    'INVALID_PHONE': 'El teléfono no es válido.',
    'UNKNOWN_MUNICIPALITY': 'El municipio no existe.',
    'INCORRECT_CURRENT_PASSWORD': 'La contraseña actual no es correcta.',
    'INCIDENT_NOTE_REQUIRED': 'Explica qué pasó en la nota.',
    'NO_BUSINESS_CASH': 'La caja del negocio no maneja esa moneda.',
    'FIXED_RATE': 'La tasa de este corredor siempre es 1.',
    'FEE_PERCENTAGE_TOO_HIGH': 'Un porcentaje de comisión no puede pasar de 100.',
    'INVALID_FEE_RANGE': 'La comisión mínima no puede ser mayor que la máxima.',
    'CORRIDOR_NOT_FOUND': 'No se encontró el corredor.',
    'EMAIL_TAKEN': 'Ya hay un usuario con ese correo.',
    'CANNOT_DEACTIVATE_SELF': 'No puedes desactivar tu propia cuenta.',
    'LAST_ADMIN': 'Debe quedar al menos un administrador activo.',
    'PERMISSION_ESCALATION': 'No puedes dar permisos que tú no tienes.',
    'UNKNOWN_ROLES': 'Alguno de los roles ya no existe. Recarga e inténtalo de nuevo.',
    'USER_NOT_FOUND': 'No se encontró el usuario.',
    'ROLE_NOT_FOUND': 'No se encontró el rol.',
    'ROLE_CODE_TAKEN': 'Ya hay un rol con ese código.',
    'ROLE_IN_USE': 'El rol está asignado a usuarios; quítaselo antes de eliminarlo.',
    'BUILT_IN_ROLE': 'Este rol viene con el sistema y no se puede cambiar.',
    'UNKNOWN_PERMISSIONS': 'Alguno de los permisos ya no existe. Recarga e inténtalo de nuevo.',
  };

  // Login
  static const loginTitle = 'Iniciar sesión';
  static const email = 'Correo electrónico';
  static const password = 'Contraseña';
  static const enter = 'Entrar';
  static const emailRequired = 'Escribe tu correo';
  static const emailInvalid = 'Correo no válido';
  static const passwordRequired = 'Escribe tu contraseña';
  static const requiredField = 'Obligatorio';
  static const amount = 'Monto';

  // Assigning
  static const courier = 'Repartidor';
  static const assignCourier = 'Asignar repartidor';
  static const reassignCourier = 'Reasignar repartidor';
  static const assign = 'Asignar';
  static const noCouriers = 'No hay repartidores disponibles.';
  static String openRemittances(int count) => count == 1 ? '1 remesa abierta' : '$count remesas abiertas';
  static const currency = 'Moneda';
  static const noteOptional = 'Nota (opcional)';
  static const amountRequired = 'Escribe un monto mayor que 0';

  // Currency exchange
  static const exchangeTitle = 'Cambiar moneda';
  static const exchangeAmount = 'Monto que cambias';
  static const exchangeRate = 'Tasa a la que cambiaste';
  static const exchangeConfirm = 'Registrar cambio';
  static const exchangeHint = 'Escribe el monto y la tasa para ver lo que recibes.';
  static const exchange = 'Cambio de moneda';
  static String exchangeResult(String from, String to) => 'Entregas $from y recibes $to';
  static String exchangeRateValue(String rate) => 'a $rate CUP por USD';
  static String registeredNotAssigned(String reason) => 'Remesa registrada, pero no se pudo asignar: $reason';
  static const showPassword = 'Mostrar contraseña';
  static const hidePassword = 'Ocultar contraseña';

  // Passwords
  static const changePassword = 'Cambiar contraseña';
  static const currentPassword = 'Contraseña actual';
  static const newPassword = 'Contraseña nueva';
  static const repeatPassword = 'Repite la contraseña nueva';
  static const passwordHint = 'Entre 8 y 72 caracteres';
  static const passwordTooShort = 'Al menos 8 caracteres';
  static const passwordTooLong = 'Como máximo 72 caracteres';
  static const passwordsDiffer = 'No coincide con la contraseña nueva';
  static const samePassword = 'Debe ser distinta de la actual';
  static const changePasswordHelp = 'Al cambiarla se cerrará tu sesión en todos los dispositivos.';
  static const passwordChanged = 'Contraseña cambiada. Entra con la contraseña nueva.';

  // Roles
  /// The roles the backend seeds, by code: (English name, English description, Spanish name, Spanish description).
  /// The backend keeps them in English; SALES and DELIVERY can be renamed, and a renamed one shows as typed.
  static const _systemRoles = {
    'ADMIN': ('Administrator', 'Full access to the system', 'Administrador', 'Acceso completo al sistema'),
    'SALES': ('Sales', 'Registers and charges remittances', 'Ventas', 'Registra y cobra las remesas'),
    'DELIVERY': (
      'Delivery',
      'Delivers remittances to beneficiaries',
      'Repartidor',
      'Entrega las remesas a los beneficiarios',
    ),
  };

  /// The role's name in Spanish while it keeps the backend's original English one.
  static String roleName(String code, String name) {
    final seed = _systemRoles[code];
    return seed != null && name == seed.$1 ? seed.$3 : name;
  }

  /// A system role's name in Spanish by its code (`SALES` → Ventas); others keep the code.
  static String roleCode(String code) => _systemRoles[code]?.$3 ?? code;

  /// The role's description in Spanish while it keeps the backend's original English one.
  static String? roleDescription(String code, String? description) {
    final seed = _systemRoles[code];
    return seed != null && description == seed.$2 ? seed.$4 : description;
  }

  // Common
  static const retry = 'Reintentar';
  static const logout = 'Cerrar sesión';
  static const cancel = 'Cancelar';
  static const confirm = 'Confirmar';
  static const empty = 'No hay nada que mostrar.';

  // Remittances
  static const late = 'Atrasada';
  static const postpone = 'Aplazar';

  // Incidents
  static const reportIncident = 'No se pudo entregar';
  static const reportIncidentPickup = 'No se pudo recoger';
  static const incidentTitle = '¿Qué pasó?';
  static const incidentNote = 'Nota';
  static const incidentNoteOptional = 'Nota (opcional)';
  static const incidentNoteRequired = 'Explica qué pasó';
  static const report = 'Reportar';
  static const incidentReported = 'Incidencia reportada';
  static const incident = 'Incidencia';

  /// Name of a remittance status, by its code and the remittance [type]: the
  /// final status is "Entregada" for a delivery and "Recogida" for a pickup;
  /// without a type (filters, counts) it names both. Unknown codes show
  /// [fallback], the backend's name, or the code itself.
  static String statusName(String code, {RemittanceType? type, String? fallback}) => switch ((code, type)) {
    ('PAID', _) => 'Pagada',
    ('ASSIGNED', _) => 'Asignada',
    ('DELIVERED', RemittanceType.delivery) => 'Entregada',
    ('DELIVERED', RemittanceType.pickup) => 'Recogida',
    ('DELIVERED', null) => 'Entregada o recogida',
    _ => fallback == null || fallback.isEmpty ? code : fallback,
  };

  static const review = 'Revisar';
  static const toReview = 'Para revisar';

  static String reviewReason(ReviewReason reason) => switch (reason) {
    ReviewReason.deliveredAfterReassignment => 'Entregada después de reasignarla',
    ReviewReason.pinMismatch => 'Entregada sin conexión con un PIN que no coincide',
    ReviewReason.duplicateDelivery => 'Dos personas dicen haberla entregado',
    ReviewReason.lateSync => 'Sincronizada más de 7 días después',
    ReviewReason.unusualExchangeRate => 'Tasa de cambio lejos de la configurada',
    ReviewReason.other => 'Marcada para revisión',
  };

  static String incidentReason(IncidentReason reason) => switch (reason) {
    IncidentReason.notHome => 'No estaba en casa',
    IncidentReason.wrongAddress => 'Dirección errónea',
    IncidentReason.unreachable => 'No contesta el teléfono',
    IncidentReason.refused => 'No la acepta',
    IncidentReason.other => 'Otro motivo',
  };

  // Complete dialog
  static const confirmDelivery = 'Confirmar entrega';
  static const confirmCollection = 'Confirmar recogida';
  static const pin = 'PIN del beneficiario';
  static const pinHint = 'Opcional si el remitente no recibió PIN';
  static const note = 'Nota (opcional)';

  // Postpone dialog
  static const postponeTitle = 'Aplazar remesa';
  static const newDate = 'Nueva fecha';
  static const reason = 'Motivo';
  static const reasonRequired = 'Escribe el motivo';
  static const delivery = 'Entrega';
  static const pickup = 'Recogida';
}
