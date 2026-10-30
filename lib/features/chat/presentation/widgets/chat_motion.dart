import 'package:flutter/material.dart';

/// Cómo entra un mensaje que aparece después de cargado el hilo.
enum MessageEntranceKind {
  /// Enviado por este dispositivo (sube desde abajo a la derecha).
  own,

  /// Recibido en tiempo real o por sondeo (fade + pequeño slide).
  incoming,
}

/// Anima la entrada de un mensaje UNA vez (al montarse con [animate] true).
/// Los cambios posteriores de [animate] se ignoran: lo decide el padre al
/// detectar el mensaje nuevo, así que re-renders y reciclado no reanima.
class MessageEntrance extends StatefulWidget {
  const MessageEntrance({
    super.key,
    required this.animate,
    required this.kind,
    required this.child,
  });

  final bool animate;
  final MessageEntranceKind kind;
  final Widget child;

  @override
  State<MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<MessageEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;
  late final bool _own = widget.kind == MessageEntranceKind.own;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _own ? 240 : 220),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = _c;
    if (c == null || c.isCompleted || c.isAnimating) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      c.value = 1;
    } else {
      c.forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    final curve = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    final slide = Tween<Offset>(
      begin: Offset(0, _own ? 0.3 : 0.12),
      end: Offset.zero,
    ).animate(curve);
    Widget out = SlideTransition(
      position: slide,
      child: FadeTransition(opacity: curve, child: widget.child),
    );
    if (_own) {
      out = ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
        alignment: Alignment.bottomRight,
        child: out,
      );
    }
    return out;
  }
}

/// Entrada escalonada de una fila de lista: fade + slide hacia arriba.
/// [delay] se aplica una sola vez, al montarse con [animate] true.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.animate,
    required this.delay,
    required this.child,
  });

  final bool animate;
  final Duration delay;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  static const _dur = 260;
  AnimationController? _c;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      final total = _dur + widget.delay.inMilliseconds;
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: total),
      );
      _c = c;
      _curve = CurvedAnimation(
        parent: c,
        curve: Interval(
          widget.delay.inMilliseconds / total,
          1,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = _c;
    if (c == null || c.isCompleted || c.isAnimating) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      c.value = 1;
    } else {
      c.forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c == null) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}
