/// Interruptores de las optimizaciones de tiempo real (Fase 3 del plan de
/// rendimiento). Encendidos por defecto; se apagan en un build sin tocar
/// código con `--dart-define=PF_PATCH_THREAD=false` o
/// `--dart-define=PF_PATCH_LIST=false`, y entonces vuelve el comportamiento
/// anterior (recargar por HTTP ante cada evento).
///
/// Los flags solo controlan parche vs recarga. Los arreglos de casado de ticks
/// por message_id y de pertenencia por chat.id (D5/D10) NO dependen de ellos
/// porque corrigen bugs: aplican siempre.
library;

/// Aplica los mensajes nuevos del evento realtime directamente al hilo abierto
/// en vez de recargar la primera página.
const pfPatchThread = bool.fromEnvironment(
  'PF_PATCH_THREAD',
  defaultValue: true,
);

/// Aplica los eventos realtime a la lista de chats (último mensaje, orden, no
/// leídos, estado) en vez de recargar la primera página.
const pfPatchList = bool.fromEnvironment('PF_PATCH_LIST', defaultValue: true);
