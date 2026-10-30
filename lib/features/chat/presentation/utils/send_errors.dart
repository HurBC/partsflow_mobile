/// Errores de envío de WhatsApp (Meta) en español, replicando
/// `codeToKey` + `Errors.*` del BO (ClientChatMessage.module.websocket.tsx,
/// messages/es/chat/clientChat.json).
const _windowCode = 131047;

const _texts = <int, String>{
  0: 'Error de autenticación. Es posible que el token haya expirado o sea inválido. Obtén un nuevo token.',
  190:
      'Error de autenticación. Es posible que el token haya expirado o sea inválido. Obtén un nuevo token.',
  131000: 'Error interno del servidor. Intenta de nuevo o contacta soporte.',
  131026:
      'El número del destinatario no es un número de WhatsApp válido o el usuario no aceptó las condiciones. Verifica el número y que el destinatario tenga la app actualizada.',
  131021: 'El destinatario no puede ser el emisor. Revisa el número destino.',
  131037:
      'El número de negocio requiere aprobación del nombre visible antes de poder enviar mensajes.',
  131042:
      'Problema con la facturación o método de pago. Revisa la configuración de facturación de la cuenta de WhatsApp Business.',
  131048:
      'Se alcanzó un límite de envío (posible bloqueo por calidad/spam). Revisa la calidad de la cuenta y reduce la tasa de envíos.',
  131050:
      'Este usuario dejó de recibir mensajes de marketing. No es posible enviarle mensajes de marketing.',
  131051:
      'Tipo de mensaje no compatible con el endpoint. Revisa el tipo de contenido que intentas enviar.',
  131052:
      'No se pudo descargar el archivo multimedia enviado por el usuario. Pídele que lo reenvíe por otro canal.',
  131053:
      'No se pudo subir el contenido multimedia. Verifica que el tipo de archivo sea admitido y vuelve a intentarlo.',
  131049:
      'Meta decidió no entregar el mensaje. Espacia reintentos y revisa límites de entrega.',
  _windowCode:
      'Mensaje no enviado: la ventana de 24 horas expiró. Para continuar, empieza la conversación con una plantilla y espera una respuesta.',
  131005: 'Acceso denegado. Comprueba permisos y tokens de acceso.',
  131008: 'Falta un parámetro obligatorio en la solicitud.',
  131009: 'El valor de uno o más parámetros no es válido.',
  131016: 'Servicio temporalmente no disponible. Intenta nuevamente más tarde.',
};

const _generic =
    'Mensaje no enviado. Intenta nuevamente más tarde o contacta al soporte.';

String sendErrorText(int code) => _texts[code] ?? _generic;

/// 131047: fuera de la ventana de 24 h; la salida es enviar una plantilla.
bool isWindowError(int code) => code == _windowCode;
