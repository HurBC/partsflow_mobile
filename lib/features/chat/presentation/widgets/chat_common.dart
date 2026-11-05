import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/image_sizing.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/theme/pf_motion.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.chat,
    this.size = 48,
    this.showJulia = false,
  });

  final Chat chat;
  final double size;
  final bool showJulia;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final name = chatDisplayName(chat);
    final (bg, fg) = avatarColors(name);
    final url = chat.imageUrl;

    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size >= 48 ? 16 : 15,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );

    final avatar = (url == null || url.isEmpty)
        ? initials
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              memCacheWidth: decodePx(context, size),
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => initials,
              placeholder: (_, _) => initials,
            ),
          );

    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            if (showJulia)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: pf.mint,
                    shape: BoxShape.circle,
                    border: Border.all(color: pf.surface, width: 2),
                  ),
                  child: Icon(Icons.auto_awesome, size: 11, color: pf.onMint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado de error con "Reintentar" (nunca una pantalla en blanco).
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: pf.text2),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: pf.textMid),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle visual (track + knob) usado en la hoja de filtros y en Julia.
///
/// Con [onIcon]/[offIcon] muestra un ícono en la perilla que cambia con "pop".
/// Con [celebrate], al pasar a ON lanza una ráfaga de puntos menta.
class PfSwitch extends StatefulWidget {
  const PfSwitch({
    super.key,
    required this.value,
    this.width = 52,
    this.height = 32,
    this.knob = 24,
    this.inset = 4,
    this.offColor,
    this.onIcon,
    this.offIcon,
    this.celebrate = false,
  });

  final bool value;
  final double width;
  final double height;
  final double knob;
  final double inset;
  final Color? offColor;
  final IconData? onIcon;
  final IconData? offIcon;
  final bool celebrate;

  @override
  State<PfSwitch> createState() => _PfSwitchState();
}

class _PfSwitchState extends State<PfSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: PfMotion.switchBurst,
  );

  @override
  void didUpdateWidget(PfSwitch old) {
    super.didUpdateWidget(old);
    if (widget.celebrate &&
        widget.value &&
        !old.value &&
        !MediaQuery.disableAnimationsOf(context)) {
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Widget _knobChild(PfColors pf, Color primary, bool reduce) {
    final icon = widget.value ? widget.onIcon : widget.offIcon;
    if (widget.onIcon == null && widget.offIcon == null) {
      return const SizedBox.shrink();
    }
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : PfMotion.switchIconPop,
      switchInCurve: PfMotion.overshoot,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => AnimatedBuilder(
        animation: anim,
        builder: (context, _) => Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: -0.698 * (1 - anim.value),
            child: Transform.scale(scale: anim.value, child: child),
          ),
        ),
      ),
      child: icon == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Icon(
              icon,
              key: ValueKey(widget.value),
              size: widget.knob * 0.7,
              color: widget.value ? primary : (widget.offColor ?? pf.border),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final on = Theme.of(context).colorScheme.primary;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final knobDur = reduce ? PfMotion.reducedFade : PfMotion.switchKnob;
    final trackDur = reduce ? PfMotion.reducedFade : PfMotion.switchTrack;
    final knob = Container(
      width: widget.knob,
      height: widget.knob,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: _knobChild(pf, on, reduce),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: trackDur,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.value ? on : (widget.offColor ?? pf.border),
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: AnimatedAlign(
            duration: knobDur,
            curve: reduce ? Curves.linear : PfMotion.overshoot,
            alignment: widget.value
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.all(widget.inset),
              child: knob,
            ),
          ),
        ),
        if (widget.celebrate)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BurstPainter(
                    _burst,
                    color: pf.mint,
                    center: Offset(
                      widget.width - widget.inset - widget.knob / 2,
                      widget.height / 2,
                    ),
                    dot: (widget.knob / 8).clamp(1.5, 3.0),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ráfaga de 6 puntos que se alejan ~24 px de la perilla y se desvanecen.
class _BurstPainter extends CustomPainter {
  _BurstPainter(
    this.anim, {
    required this.color,
    required this.center,
    required this.dot,
  }) : super(repaint: anim);

  final Animation<double> anim;
  final Color color;
  final Offset center;
  final double dot;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    if (t <= 0 || t >= 1) return;
    final dist = 24 * Curves.easeOutCubic.transform(t);
    final paint = Paint()..color = color.withValues(alpha: 1 - t);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * dist,
        dot * (1 - t * 0.4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.color != color || old.center != center || old.dot != dot;
}

/// Barra superior de una hoja modal (agarre).
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      decoration: BoxDecoration(
        color: PfColors.of(context).border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
