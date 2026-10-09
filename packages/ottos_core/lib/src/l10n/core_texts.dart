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
  static const delivery = 'Entrega';
  static const pickup = 'Recogida';
}
