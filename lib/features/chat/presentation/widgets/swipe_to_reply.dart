import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';

/// Desliza a la derecha para responder. Solo arrastre horizontal hacia la
/// derecha, con resistencia; el ícono sigue el progreso y al soltar pasado el
/// umbral se llama [onReply]. Siempre vuelve a su sitio con animación.
///
/// Gana el hijo en los conflictos horizontales (p. ej. el slider de audio):
/// el reconocedor más profundo recibe primero el movimiento.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.enabled,
    required this.onReply,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onReply;
  final Widget child;

  static const maxDx = 72.0;
  static const threshold = 56.0;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  final _dx = ValueNotifier<double>(0);
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(_onBack);
  double _raw = 0;
  double _from = 0;
  bool _crossed = false;

  @override
  void dispose() {
    _back.dispose();
    _dx.dispose();
    super.dispose();
  }

  void _onBack() {
    _dx.value = _from * (1 - Curves.easeOut.transform(_back.value));
  }

  void _start(DragStartDetails _) {
    _back.stop();
    _raw = _dx.value == 0 ? 0 : _rawFor(_dx.value);
    _crossed = _dx.value >= SwipeToReply.threshold;
  }

  // Resistencia exponencial: dx = max * (1 - e^(-raw / k)).
  static const _k = 45.0;
  static double _rawFor(double dx) =>
      -_k * math.log(1 - (dx / SwipeToReply.maxDx).clamp(0, 0.999));

  void _update(DragUpdateDetails d) {
    _raw = math.max(0, _raw + d.delta.dx);
    final dx = SwipeToReply.maxDx * (1 - math.exp(-_raw / _k));
    _dx.value = dx;
    if (!_crossed && dx >= SwipeToReply.threshold) {
      _crossed = true;
      HapticFeedback.lightImpact();
    }
  }

  void _end(DragEndDetails _) {
    final fire = _dx.value >= SwipeToReply.threshold;
    _settle();
    if (fire) widget.onReply();
  }

  void _settle() {
    _from = _dx.value;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final pf = PfColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _start,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: _settle,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: ValueListenableBuilder<double>(
                  valueListenable: _dx,
                  builder: (context, dx, _) {
                    final p = (dx / SwipeToReply.threshold).clamp(0.0, 1.0);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Opacity(
                          opacity: p,
                          child: Transform.scale(
                            scale: 0.5 + 0.5 * p,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: pf.divider,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.reply_rounded,
                                size: 20,
                                color: pf.textMid,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _dx,
            child: widget.child,
            builder: (context, dx, child) =>
                Transform.translate(offset: Offset(dx, 0), child: child),
          ),
        ],
      ),
    );
  }
}
