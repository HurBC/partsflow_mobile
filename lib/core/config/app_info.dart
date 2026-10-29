/// Versión mostrada en Perfil. Mantener alineada con `version:` de pubspec.yaml.
const appVersion = '1.0.0';

/// Entorno inyectado con `--dart-define-from-file=env/<entorno>.json`.
const appEnv = String.fromEnvironment('APP_ENV');

/// Tiempo real (WebSocket). Sin ambos valores la app solo usa sondeo.
const wsBaseUrl = String.fromEnvironment('WS_BASE_URL');
const wsOrigin = String.fromEnvironment('WS_ORIGIN');
