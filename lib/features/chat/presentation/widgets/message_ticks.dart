import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_motion.dart';

/// Ticks de estado: read ✓✓ (color de leído), delivered ✓✓, sent ✓,
/// temp/pending/stale reloj, error ícono de error.
///
/// Los checks se dibujan (trazo) al PASAR a enviado/entregado y el leído hace
/// un pop con cambio de color; montarse ya en ese estado no anima.
class MessageTicks extends StatefulWidget {
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
  State<MessageTicks> createState() => _MessageTicksState();
}

int _checks(String? s) => switch (s) {
  'sent' => 1,
  'delivered' || 'read' => 2,
  _ => 0,
};

class _MessageTicksState extends State<MessageTicks>
    with SingleTickerProviderStateMixin {
  // Solo existe tras la primera transición animada: en reposo no hay
  // controladores ni builders (hilos largos = muchos ticks).
  AnimationController? _c;
  bool _drawFirst = false;
  bool _drawSecond = false;
  bool _popRead = false;
  bool _fadeIn = false;

  @override
  void didUpdateWidget(MessageTicks old) {
    super.didUpdateWidget(old);
    if (old.status == widget.status) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final from = _checks(old.status);
    final to = _checks(widget.status);
    _drawFirst = to > from && from < 1;
    _drawSecond = to > from && to >= 2;
    _popRead = widget.status == 'read' && old.status != 'read';
    _fadeIn = to == 0;
    final c = _c ??= AnimationController(
      vsync: this,
      duration: PfMotion.tickDraw,
    );
    c.forward(from: 0);
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _checkPaint(Color color, double first, double second) => CustomPaint(
    size: Size.square(widget.size),
    painter: _CheckPainter(color: color, first: first, second: second),
  );

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final n = _checks(status);
    final target = status == 'read' ? widget.readColor : widget.color;
    final c = _c;
    final Widget inner;
    if (n > 0) {
      if (c == null) {
        inner = _checkPaint(target, 1, n >= 2 ? 1 : 0);
      } else {
        inner = AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final p = c.value;
            final first = _drawFirst ? p : 1.0;
            final second = n < 2 ? 0.0 : (_drawSecond ? p : 1.0);
            final color = _popRead
                ? Color.lerp(widget.color, widget.readColor, p)!
                : target;
            final scale = _popRead && p < 1
                ? 1 + 0.3 * (1 - (2 * p - 1).abs())
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: _checkPaint(color, first, second),
            );
          },
        );
      }
    } else {
      final (icon, col) = switch (status) {
        'error' => (Icons.error_outline, widget.errorColor ?? widget.color),
        'temp' || 'pending' || 'stale' => (Icons.schedule, widget.color),
        _ => (null, widget.color),
      };
      if (icon == null) return const SizedBox.shrink();
      final ic = Icon(icon, size: widget.size, color: col);
      inner = c != null && _fadeIn ? FadeTransition(opacity: c, child: ic) : ic;
    }
    return Semantics(
      label: MessageTicks.labelFor(status),
      child: ExcludeSemantics(
        child: SizedBox.square(dimension: widget.size, child: inner),
      ),
    );
  }
}

/// Dibuja ✓ o ✓✓ con trazo progresivo (PathMetric). Base 24×24.
class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.color,
    required this.first,
    required this.second,
  });

  final Color color;
  final double first;
  final double second;

  static Path _check(double dx) => Path()
    ..moveTo(2 + dx, 12.5)
    ..lineTo(6.5 + dx, 17)
    ..lineTo(16.5 + dx, 7);

  void _stroke(Canvas canvas, Path path, double p, Paint paint) {
    if (p <= 0) return;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * p.clamp(0.0, 1.0)), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Con un solo check se centra; al aparecer el segundo se desliza a su sitio.
    final shift = 2.5 * (1 - second);
    canvas.translate(shift, 0);
    _stroke(canvas, _check(0), first, paint);
    _stroke(canvas, _check(5), second, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter o) =>
      o.color != color || o.first != first || o.second != second;
}
