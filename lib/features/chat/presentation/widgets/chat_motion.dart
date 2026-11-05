import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_motion.dart';
import 'package:partsflow_mobile/core/ui/pf_haptics.dart';

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
  CurvedAnimation? _pop;
  CurvedAnimation? _fade;
  late final bool _own = widget.kind == MessageEntranceKind.own;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c = AnimationController(
        vsync: this,
        duration: _own
            ? PfMotion.bubbleEnter
            : const Duration(milliseconds: 220),
      );
      final c = _c!;
      if (_own) {
        // Rebote desde abajo-derecha + fundido corto (sin pasar de opacidad 1).
        _pop = CurvedAnimation(parent: c, curve: PfMotion.overshoot);
        _fade = CurvedAnimation(
          parent: c,
          curve: const Interval(0, 0.5, curve: Curves.easeOut),
        );
      } else {
        _pop = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
      }
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
    _pop?.dispose();
    _fade?.dispose();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    if (_own) {
      final pop = _pop!;
      final fade = _fade!;
      // Nace desde abajo-derecha: translate(26,40) + scale .55→1 con rebote.
      return AnimatedBuilder(
        animation: c,
        child: widget.child,
        builder: (context, child) {
          final t = pop.value;
          return Opacity(
            opacity: fade.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(26 * (1 - t), 40 * (1 - t)),
              child: Transform.scale(
                scale: 0.55 + 0.45 * t,
                alignment: Alignment.bottomRight,
                child: child,
              ),
            ),
          );
        },
      );
    }
    final curve = _pop!;
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(curve),
      child: FadeTransition(opacity: curve, child: widget.child),
    );
  }
}

/// Sacude [child] (~420 ms) cada vez que [error] pasa de false a true y dispara
/// la háptica de error UNA vez por transición. Montarse ya en error (reabrir
/// el chat con mensajes fallidos) o reconstruir en error no hace nada.
class ErrorShake extends StatefulWidget {
  const ErrorShake({
    super.key,
    required this.error,
    required this.child,
    this.onError = PfHaptics.error,
  });

  final bool error;
  final Widget child;
  final VoidCallback onError;

  @override
  State<ErrorShake> createState() => _ErrorShakeState();
}

class _ErrorShakeState extends State<ErrorShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: PfMotion.errorShake,
  );

  @override
  void didUpdateWidget(ErrorShake old) {
    super.didUpdateWidget(old);
    if (widget.error && !old.error) {
      widget.onError();
      if (!MediaQuery.disableAnimationsOf(context)) _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        if (t == 0 || t == 1) return child!;
        final dx = math.sin(t * math.pi * 6) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
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
