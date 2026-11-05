import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/theme/pf_motion.dart';

/// Pinta barras verticales redondeadas centradas. [progress] (0..1) pinta las
/// primeras barras con [color] y el resto con [color] atenuado.
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.bars,
    required this.color,
    this.progress = 1,
    this.minFraction = 0.12,
    this.alignRight = false,
  });

  final List<double> bars;
  final Color color;
  final double progress;
  final double minFraction;

  /// En vivo (barras que se desplazan) las muestras se alinean al borde derecho.
  final bool alignRight;

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    if (n == 0) return;
    final slot = size.width / n;
    final w = slot * 0.55;
    final on = Paint()..color = color;
    final off = Paint()..color = color.withValues(alpha: 0.3);
    for (var i = 0; i < n; i++) {
      final v = bars[i].clamp(0.0, 1.0);
      final h = size.height * (minFraction + (1 - minFraction) * v);
      final cx = slot * i + slot / 2;
      final played = (i + 0.5) / n <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, size.height / 2),
            width: w,
            height: h,
          ),
          Radius.circular(w / 2),
        ),
        played ? on : off,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.bars != bars || old.color != color || old.progress != progress;
}

/// Onda en vivo (~24 barras que se desplazan) + punto rojo que "respira" +
/// tiempo. Presentación pura: los datos llegan por [bars].
class RecordingPill extends StatefulWidget {
  const RecordingPill({
    super.key,
    required this.bars,
    required this.time,
    required this.reduceMotion,
  });

  final ValueListenable<List<double>> bars;
  final String time;
  final bool reduceMotion;

  @override
  State<RecordingPill> createState() => _RecordingPillState();
}

class _RecordingPillState extends State<RecordingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: PfMotion.recDotBreath,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RecordingPill old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion) {
      _breath
        ..stop()
        ..value = 0;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        AnimatedBuilder(
          animation: _breath,
          builder: (_, _) {
            final t = Curves.easeInOut.transform(_breath.value);
            return Opacity(
              opacity: 1 - 0.45 * t,
              child: Transform.scale(
                scale: 1 - 0.2 * t,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: pf.errIcon,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          widget.time,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: pf.text,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 28,
            child: RepaintBoundary(
              child: ValueListenableBuilder<List<double>>(
                valueListenable: widget.bars,
                builder: (_, bars, _) => CustomPaint(
                  painter: WaveformPainter(bars: bars, color: primary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Anillo alrededor del botón de enviar proporcional a la amplitud (0..1).
class AmplitudeRing extends StatelessWidget {
  const AmplitudeRing({
    super.key,
    required this.amplitude,
    required this.color,
    required this.reduceMotion,
    required this.child,
  });

  final ValueListenable<double> amplitude;
  final Color color;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: amplitude,
                builder: (_, a, _) => TweenAnimationBuilder<double>(
                  tween: Tween(end: a),
                  duration: PfMotion.recAmpSample,
                  builder: (_, v, _) => Transform.scale(
                    scale: 1 + 0.45 * v,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.28 * v),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Onda con progreso de reproducción; tocar/arrastrar busca una posición.
class WaveformSeekBar extends StatelessWidget {
  const WaveformSeekBar({
    super.key,
    required this.bars,
    required this.color,
    required this.progress,
    required this.onSeek,
  });

  final List<double> bars;
  final Color color;
  final double progress;

  /// Fracción 0..1; null desactiva la interacción.
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        void seek(Offset p) =>
            onSeek?.call((p.dx / c.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onSeek == null ? null : (d) => seek(d.localPosition),
          onHorizontalDragUpdate: onSeek == null
              ? null
              : (d) => seek(d.localPosition),
          child: SizedBox(
            height: 30,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                bars: bars,
                color: color,
                progress: progress,
              ),
            ),
          ),
        );
      },
    );
  }
}
