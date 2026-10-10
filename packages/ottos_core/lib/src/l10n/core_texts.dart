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
    'INVALID_POSTPONE_DATE': 'La nueva fecha debe ser posterior a la fecha prevista.',
    'REMITTANCE_NOT_FOUND': 'No se encontró la remesa.',
    'REMITTANCE_ALREADY_COMPLETED': 'La remesa ya está completada.',
    'REMITTANCE_NOT_ASSIGNABLE': 'La remesa no se puede asignar en su estado actual.',
    'REMITTANCE_NOT_COMPLETABLE': 'La remesa no se puede completar en su estado actual.',
    'TRANSITION_NOT_ALLOWED': 'Ese cambio de estado no está permitido.',
    'TRANSITION_FORBIDDEN': forbidden,
    'CUSTOMER_NOT_FOUND': 'No se encontró el remitente.',
    'BENEFICIARY_NOT_FOUND': 'No se encontró el beneficiario.',
    'PHONE_ALREADY_REGISTERED': 'Ya hay un cliente con ese teléfono.',
    'INVALID_PHONE': 'El teléfono no es válido.',
    'UNKNOWN_MUNICIPALITY': 'El municipio no existe.',
    'INCORRECT_CURRENT_PASSWORD': 'La contraseña actual no es correcta.',
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
  static const showPassword = 'Mostrar contraseña';
  static const hidePassword = 'Ocultar contraseña';

  // Common
  static const retry = 'Reintentar';
  static const logout = 'Cerrar sesión';
  static const cancel = 'Cancelar';
  static const confirm = 'Confirmar';
  static const empty = 'No hay nada que mostrar.';

  // Remittances
  static const late = 'Atrasada';
  static const postpone = 'Aplazar';

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
