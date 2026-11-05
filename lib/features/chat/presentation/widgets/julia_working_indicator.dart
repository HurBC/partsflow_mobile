import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/theme/pf_motion.dart';

/// Texto del indicador (también etiqueta de accesibilidad).
const juliaWorkingText = 'Julia está revisando el chat…';

/// "Julia está revisando el chat…": burbuja con 3 puntos + avatar animado.
/// Entra con fade+slide-up; con [visible] en false se desvanece (la página lo
/// retira tras [PfMotion.juliaWorkingExit]).
class JuliaWorkingIndicator extends StatefulWidget {
  const JuliaWorkingIndicator({super.key, this.visible = true});

  final bool visible;

  @override
  State<JuliaWorkingIndicator> createState() => _JuliaWorkingIndicatorState();
}

class _JuliaWorkingIndicatorState extends State<JuliaWorkingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: PfMotion.juliaWorkingEnter,
    reverseDuration: PfMotion.juliaWorkingExit,
  );
  late final Animation<double> _size = CurvedAnimation(
    parent: _enter,
    curve: Curves.easeOutCubic,
  );
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: PfMotion.juliaDots,
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: PfMotion.juliaSpin,
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduce && _enter.value > 0) return;
    _reduce = reduce;
    if (reduce) {
      _dots.stop();
      _spin.stop();
      _enter.duration = PfMotion.reducedFade;
    } else {
      _enter.duration = PfMotion.juliaWorkingEnter;
      if (!_dots.isAnimating) _dots.repeat();
      if (!_spin.isAnimating) _spin.repeat();
    }
    if (widget.visible && _enter.status == AnimationStatus.dismissed) {
      _enter.forward();
    }
  }

  @override
  void didUpdateWidget(JuliaWorkingIndicator old) {
    super.didUpdateWidget(old);
    if (old.visible && !widget.visible) {
      _enter.reverse();
    } else if (!old.visible && widget.visible) {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _dots.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic));
    return Semantics(
      liveRegion: true,
      label: juliaWorkingText,
      child: ExcludeSemantics(
        child: SizeTransition(
          sizeFactor: _size,
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: FadeTransition(
              opacity: _enter,
              child: AnimatedBuilder(
                animation: _enter,
                builder: (context, child) => Transform.translate(
                  offset: _reduce ? Offset.zero : slide.evaluate(_enter) * 24,
                  child: child,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _DotsBubble(anim: _dots, reduce: _reduce),
                          const SizedBox(width: 8),
                          _SpinAvatar(anim: _spin, reduce: _reduce),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Text(
                          juliaWorkingText,
                          style: TextStyle(fontSize: 12, color: pf.text2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotsBubble extends StatelessWidget {
  const _DotsBubble({required this.anim, required this.reduce});

  final Animation<double> anim;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final period = PfMotion.juliaDots.inMilliseconds;
    final stagger = PfMotion.juliaDotStagger.inMilliseconds / period;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: pf.bubbleJulia,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pf.border),
      ),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: anim,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      reduce
                          ? 0
                          : -4 *
                                math.max(
                                  0,
                                  math.sin(
                                    2 * math.pi * (anim.value - i * stagger),
                                  ),
                                ),
                    ),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: pf.text2,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpinAvatar extends StatelessWidget {
  const _SpinAvatar({required this.anim, required this.reduce});

  final Animation<double> anim;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          final breathe = reduce
              ? 0.0
              : (math.sin(2 * math.pi * anim.value) + 1) / 2;
          return SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 1 + 0.25 * breathe,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: pf.mint.withValues(alpha: 0.7 - 0.45 * breathe),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: pf.juliaBg,
                    shape: BoxShape.circle,
                  ),
                  child: Transform.rotate(
                    angle: reduce ? 0 : 2 * math.pi * anim.value,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: pf.juliaFg,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
