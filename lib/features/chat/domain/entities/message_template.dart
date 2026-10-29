/// Variable `{{n}}` de un componente de plantilla.
class TemplateVariable {
  const TemplateVariable({required this.component, required this.index});

  /// Posición del componente dentro de `components`.
  final int component;
  final int index;

  String get key => '$component:$index';
}

class TemplateComponent {
  const TemplateComponent({
    required this.type,
    this.format,
    this.text,
    required this.raw,
  });

  /// HEADER | BODY | FOOTER | BUTTONS (mayúsculas).
  final String type;
  final String? format;
  final String? text;

  /// Componente tal como vino del servidor (se reenvía sin tocar).
  final Map<String, dynamic> raw;

  /// Índices `{{n}}` distintos, ascendentes.
  List<int> get variableIndexes {
    final t = text;
    if (t == null) return const [];
    final set = <int>{
      for (final m in RegExp(r'\{\{\s*(\d+)\s*\}\}').allMatches(t))
        int.parse(m.group(1)!),
    };
    return set.toList()..sort();
  }
}

class MessageTemplate {
  const MessageTemplate({
    required this.id,
    required this.name,
    required this.language,
    required this.status,
    this.category,
    this.components = const [],
    this.message,
  });

  final String id;
  final String name;
  final String language;
  final String status;
  final String? category;
  final List<TemplateComponent> components;
  final String? message;

  /// Variables que hay que pedir (header/body/footer).
  List<TemplateVariable> get variables => [
    for (var i = 0; i < components.length; i++)
      if (const {'HEADER', 'BODY', 'FOOTER'}.contains(components[i].type))
        for (final n in components[i].variableIndexes)
          TemplateVariable(component: i, index: n),
  ];

  /// Motivo por el que la app no puede enviarla (igual que el BO), o null.
  String? get unsupportedReason {
    for (final c in components) {
      if (c.type == 'HEADER' &&
          const {'IMAGE', 'VIDEO', 'DOCUMENT'}.contains(c.format)) {
        return 'Incluye imagen, video o documento: envíala desde el Backoffice';
      }
      if (c.type == 'BUTTONS' && c.variableIndexes.isNotEmpty) {
        return 'Tiene botones con variables: envíala desde el Backoffice';
      }
      if (c.type == 'BUTTONS' && _buttonsHaveVariables(c.raw)) {
        return 'Tiene botones con variables: envíala desde el Backoffice';
      }
    }
    return null;
  }

  static bool _buttonsHaveVariables(Map<String, dynamic> raw) {
    final b = raw['buttons'];
    if (b is! List) return false;
    final re = RegExp(r'\{\{\s*\d+\s*\}\}');
    for (final x in b) {
      if (x is Map && re.hasMatch('${x['url'] ?? ''}${x['text'] ?? ''}')) {
        return true;
      }
    }
    return false;
  }

  /// Texto de HEADER/BODY/FOOTER con las variables reemplazadas
  /// (`values` = key de [TemplateVariable] → valor), unidos por línea en blanco.
  String render(Map<String, String> values) {
    final parts = <String>[];
    for (var i = 0; i < components.length; i++) {
      final c = components[i];
      if (!const {'HEADER', 'BODY', 'FOOTER'}.contains(c.type)) continue;
      final t = c.text;
      if (t == null || t.isEmpty) continue;
      parts.add(
        t.replaceAllMapped(RegExp(r'\{\{\s*(\d+)\s*\}\}'), (m) {
          final v = values['$i:${m.group(1)}'];
          return (v == null || v.isEmpty) ? m.group(0)! : v;
        }),
      );
    }
    return parts.join('\n\n');
  }

  /// `components` a enviar: con variables (en orden ascendente) o tal cual.
  List<Map<String, dynamic>> buildComponents(Map<String, String> values) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < components.length; i++) {
      final c = components[i];
      final idx = const {'HEADER', 'BODY', 'FOOTER'}.contains(c.type)
          ? c.variableIndexes
          : const <int>[];
      if (idx.isEmpty) {
        out.add(c.raw);
        continue;
      }
      out.add({
        ...c.raw,
        'variables': [
          for (final n in idx) {'type': 'text', 'text': values['$i:$n'] ?? ''},
        ],
      });
    }
    return out;
  }
}
