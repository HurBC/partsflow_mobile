import 'package:flutter/material.dart';

/// Ticks de estado: read ✓✓ (color de leído), delivered ✓✓, sent ✓,
/// temp/pending/stale reloj, error ícono de error.
class MessageTicks extends StatelessWidget {
  const MessageTicks({
    super.key,
    required this.status,
    required this.color,
    required this.readColor,
    this.errorColor,
    this.size = 14,
  });

  final String? status;
  final Color color;
  final Color readColor;
  final Color? errorColor;
  final double size;

  static String labelFor(String? status) => switch (status) {
    'read' => 'Leído',
    'delivered' => 'Entregado',
    'sent' => 'Enviado',
    'error' => 'Error al enviar',
    'temp' || 'pending' || 'stale' => 'Enviando',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final (icon, c) = switch (status) {
      'read' => (Icons.done_all, readColor),
      'delivered' => (Icons.done_all, color),
      'sent' => (Icons.done, color),
      'error' => (Icons.error_outline, errorColor ?? color),
      'temp' || 'pending' || 'stale' => (Icons.schedule, color),
      _ => (null, color),
    };
    if (icon == null) return const SizedBox.shrink();
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: labelFor(status),
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
          transitionBuilder: (child, a) => ScaleTransition(
            scale: a,
            child: FadeTransition(opacity: a, child: child),
          ),
          child: Icon(icon, key: ValueKey(status), size: size, color: c),
        ),
      ),
    );
  }
}
