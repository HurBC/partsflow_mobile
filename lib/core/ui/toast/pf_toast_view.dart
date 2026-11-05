import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/app_text_schema.dart';
import 'package:partsflow_mobile/core/theme/pf_motion.dart';
import 'package:partsflow_mobile/core/ui/toast/pf_toast.dart';
import 'package:partsflow_mobile/core/ui/toast/pf_toast_palette.dart';

/// Vista animada del aviso (la crea [PfToast.show] dentro del overlay raíz).
class PfToastView extends StatefulWidget {
  const PfToastView({
    super.key,
    required this.title,
    required this.kind,
    required this.bottomClearance,
    required this.onReady,
    required this.onClosed,
    required this.isCurrent,
    this.body,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.autoClose,
  });

  final String title;
  final String? body;
  final PfToastKind kind;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration? autoClose;
  final double bottomClearance;

  /// Entrega el disparador de la salida animada al dueño.
  final void Function(VoidCallback animateOut) onReady;
  final VoidCallback onClosed;
  final bool Function() isCurrent;

  @override
  State<PfToastView> createState() => _PfToastViewState();
}

// Línea de tiempo maestra (ms): entrada 300, chip 40..320, ícono 140..660.
final _enterMs = PfMotion.toastEnter.inMilliseconds.toDouble();
final _chipFrom = PfMotion.toastChipDelay.inMilliseconds.toDouble();
final _chipTo = _chipFrom + PfMotion.toastChipPop.inMilliseconds;
final _iconFrom = PfMotion.toastIconDelay.inMilliseconds.toDouble();
double _iconTo(Duration d) => _iconFrom + d.inMilliseconds;
const _totalMs = 700.0;

double _at(double ms) => ms / _totalMs;

class _PfToastViewState extends State<PfToastView>
    with TickerProviderStateMixin {
  late final AnimationController _master = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _exit = AnimationController(vsync: this);
  AnimationController? _timer;
  bool _reduced = false;
  bool _started = false;
  bool _closing = false;
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.onReady(_animateOut);
    _exit.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onClosed();
    });
    final d = widget.autoClose;
    if (d != null) {
      _timer = AnimationController(vsync: this, duration: d)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _animateOut();
        });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _master.duration = _reduced
        ? PfMotion.reducedFade
        : const Duration(milliseconds: 700);
    _exit.duration = _reduced ? PfMotion.reducedFade : PfMotion.toastExit;
    _master.forward();
    _timer?.forward();
  }

  @override
  void dispose() {
    _master.dispose();
    _exit.dispose();
    _timer?.dispose();
    super.dispose();
  }

  void _animateOut() {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.stop();
    _exit.forward();
  }

  void _pause() => _timer?.stop();

  void _resume() {
    if (!_closing && _timer != null && !_timer!.isCompleted) _timer!.forward();
  }

  void _onAction() {
    widget.onAction?.call();
    // Si la acción mostró otro aviso, no lo cierres.
    if (widget.isCurrent()) _animateOut();
  }

  // Progreso de un tramo de la línea de tiempo (0..1); 1 si hay reducción.
  double _seg(double fromMs, double toMs, [Curve curve = Curves.linear]) {
    if (_reduced) return 1;
    return Interval(
      _at(fromMs),
      _at(toMs),
      curve: curve,
    ).transform(_master.value);
  }

  void _endDrag(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    final far = _drag.dy > 36 || _drag.dx.abs() > 90;
    final fast = v.dy > 500 || v.dx.abs() > 700;
    if (far || fast) {
      _animateOut();
    } else {
      setState(() => _drag = Offset.zero);
    }
    _resume();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final line =
        mq.viewInsets.bottom + mq.padding.bottom + widget.bottomClearance;
    final pal = PfToastPalette.of(context, widget.kind);

    final capsule = AnimatedBuilder(
      animation: Listenable.merge([_master, _exit]),
      builder: (context, child) {
        final enter = _seg(0, _enterMs, PfMotion.overshoot);
        var dy = 0.0, scale = 1.0, opacity = 1.0;
        if (_reduced) {
          opacity = _master.value * (1 - _exit.value);
        } else {
          dy = 44 * (1 - enter);
          scale = .86 + .14 * enter;
          opacity = _seg(0, _enterMs * .55).clamp(0.0, 1.0);
          final o = Curves.easeIn.transform(_exit.value);
          dy += 18 * o;
          scale *= 1 - .06 * o;
          opacity *= 1 - o;
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(_drag.dx, dy + math.max(0, _drag.dy)),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Listener(
        onPointerDown: (_) => _pause(),
        onPointerUp: (_) => _resume(),
        onPointerCancel: (_) => _resume(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => setState(() => _drag += d.delta),
          onPanEnd: _endDrag,
          onPanCancel: () => setState(() => _drag = Offset.zero),
          child: _Capsule(
            view: widget,
            pal: pal,
            icon: _AnimatedChip(state: this, pal: pal),
            timer: _timer,
            onAction: _onAction,
            onClose: _animateOut,
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: line,
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    child: capsule,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.view,
    required this.pal,
    required this.icon,
    required this.timer,
    required this.onAction,
    required this.onClose,
  });

  final PfToastView view;
  final PfToastPalette pal;
  final Widget icon;
  final AnimationController? timer;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasAction = view.actionLabel != null;
    final body = view.body;
    final fontFamily = AppTextTheme.fontFamily;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(8, 8, hasAction ? 6 : 18, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.title,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                    color: pal.title,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (body != null && body.isNotEmpty)
                  Text(
                    body,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w400,
                      color: pal.body,
                      decoration: TextDecoration.none,
                    ),
                  ),
              ],
            ),
          ),
          if (hasAction) ...[
            const SizedBox(width: 10),
            _ActionButton(label: view.actionLabel!, pal: pal, onTap: onAction),
            _CloseButton(pal: pal, onTap: onClose),
          ],
        ],
      ),
    );

    return DecoratedBox(
      key: const ValueKey('pf-toast-capsule'),
      decoration: BoxDecoration(
        color: pal.capsule,
        borderRadius: BorderRadius.circular(26),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            content,
            if (timer != null)
              Positioned(
                left: 22,
                right: 22,
                bottom: 0,
                height: 3,
                child: AnimatedBuilder(
                  animation: timer!,
                  builder: (_, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (1 - timer!.value).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: pal.bar,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.pal,
    required this.onTap,
  });

  final String label;
  final PfToastPalette pal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pal.actionBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTextTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: pal.actionFg,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.pal, required this.onTap});

  final PfToastPalette pal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar aviso',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.close_rounded, size: 18, color: pal.body),
        ),
      ),
    );
  }
}

/// Chip circular de 36 px con el ícono animado según el tipo.
class _AnimatedChip extends StatelessWidget {
  const _AnimatedChip({required this.state, required this.pal});

  final _PfToastViewState state;
  final PfToastPalette pal;

  @override
  Widget build(BuildContext context) {
    final w = state.widget;
    return AnimatedBuilder(
      animation: state._master,
      builder: (context, _) {
        final pop = state._seg(_chipFrom, _chipTo, PfMotion.overshoot);
        return Transform.rotate(
          angle: -40 * math.pi / 180 * (1 - pop),
          child: Transform.scale(
            scale: math.max(0, pop),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: pal.chipBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: _icon(w),
            ),
          ),
        );
      },
    );
  }

  double _seq(List<double> values, double t) {
    // Interpola linealmente entre [values] a lo largo de t (0..1).
    final n = values.length - 1;
    final x = (t.clamp(0.0, 1.0)) * n;
    final i = x.floor().clamp(0, n - 1);
    final f = Curves.easeOut.transform(x - i);
    return values[i] + (values[i + 1] - values[i]) * f;
  }

  Widget _icon(PfToastView w) {
    final color = pal.chipFg;
    const rad = math.pi / 180;
    final icon = w.icon;
    Widget glyph(IconData d) => Icon(d, size: 20, color: color);

    switch (w.kind) {
      case PfToastKind.loading:
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
        );
      case PfToastKind.success:
        if (icon != null) return glyph(icon);
        return CustomPaint(
          size: const Size(20, 20),
          painter: _CheckPainter(
            progress: state._seg(
              _iconFrom,
              _iconTo(PfMotion.toastIconCheck),
              Curves.easeOut,
            ),
            color: color,
          ),
        );
      case PfToastKind.julia:
        final t = state._seg(_iconFrom, _iconTo(PfMotion.toastIconJulia));
        final r = _seq([-60, 12, 0], t) * rad;
        final s = _seq([.5, 1.2, 1], t);
        if (state._reduced) return glyph(icon ?? Icons.auto_awesome_rounded);
        return Transform.rotate(
          angle: r,
          child: Transform.scale(
            scale: s,
            child: glyph(icon ?? Icons.auto_awesome_rounded),
          ),
        );
      case PfToastKind.warning:
        final t = state._seg(_iconFrom, _iconTo(PfMotion.toastIconShake));
        final r = state._reduced ? 0.0 : _seq([0, -14, 11, -7, 3, 0], t) * rad;
        return Transform.rotate(
          angle: r,
          alignment: Alignment.bottomCenter,
          child: glyph(icon ?? Icons.warning_amber_rounded),
        );
      case PfToastKind.error:
        final t = state._seg(_iconFrom, _iconTo(PfMotion.toastIconPulse));
        final s = state._reduced ? 1.0 : _seq([1, 1.28, 1], t);
        return Transform.scale(
          scale: s,
          child: glyph(icon ?? Icons.error_outline_rounded),
        );
      case PfToastKind.info:
        final t = state._seg(_iconFrom, _iconTo(PfMotion.toastIconInfo));
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: glyph(icon ?? Icons.info_outline_rounded),
        );
    }
  }
}

/// Check que se dibuja siguiendo el trazo (PathMetric).
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .22, size.height * .53)
      ..lineTo(size.width * .43, size.height * .73)
      ..lineTo(size.width * .79, size.height * .31);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
