import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';

const _shimmerLoop = Duration(milliseconds: 1300);

/// Brillo que recorre los placeholders de [child] (gradiente que se desliza).
///
/// Un solo controller por instancia: envuelve el skeleton completo, no cada
/// bloque. Solo repinta (shader), no relayout. Con animaciones desactivadas
/// deja el skeleton estático.
class PfShimmer extends StatefulWidget {
  const PfShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<PfShimmer> createState() => _PfShimmerState();
}

class _PfShimmerState extends State<PfShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _shimmerLoop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final highlight = PfColors.of(context).surface.withValues(alpha: 0.6);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: [
            highlight.withValues(alpha: 0),
            highlight,
            highlight.withValues(alpha: 0),
          ],
          stops: const [0.3, 0.5, 0.7],
          transform: _SlideTransform(_c.value),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

/// Desliza el gradiente de fuera por la izquierda a fuera por la derecha.
class _SlideTransform extends GradientTransform {
  const _SlideTransform(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}
