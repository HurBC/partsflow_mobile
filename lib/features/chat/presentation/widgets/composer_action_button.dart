import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/theme/pf_motion.dart';
import 'package:partsflow_mobile/core/ui/pf_haptics.dart';

/// Botón del composer: micrófono (sin texto) ↔ enviar (con texto).
/// Morph con rotación + escala y color interpolado; al enviar, el avión
/// "despega" y se dispara la háptica light (solo si [onSend] envió de verdad).
class ComposerActionButton extends StatefulWidget {
  const ComposerActionButton({
    super.key,
    required this.hasText,
    required this.onSend,
    required this.onRecord,
  });

  final bool hasText;

  /// Devuelve true si realmente se envió algo.
  final bool Function() onSend;
  final VoidCallback onRecord;

  @override
  State<ComposerActionButton> createState() => _ComposerActionButtonState();
}

class _ComposerActionButtonState extends State<ComposerActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _takeoff = AnimationController(
    vsync: this,
    duration: PfMotion.composerTakeoff,
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Al terminar el despegue, el fondo pasa al estado de micrófono.
    _takeoff.addStatusListener((st) {
      if (!st.isAnimating && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _takeoff.dispose();
    super.dispose();
  }

  void _tap() {
    if (!widget.hasText) {
      widget.onRecord();
      return;
    }
    if (!widget.onSend()) return;
    PfHaptics.light();
    if (!MediaQuery.disableAnimationsOf(context)) _takeoff.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final reduce = MediaQuery.disableAnimationsOf(context);
    Duration motion(Duration d) => reduce ? Duration.zero : d;
    // Durante el despegue se mantiene el fondo primary (avión blanco visible).
    final sendLook = widget.hasText || _takeoff.isAnimating;
    final bg = sendLook ? primary : pf.mint;
    final ink = sendLook ? Colors.white : pf.onMint;
    return Semantics(
      button: true,
      label: widget.hasText ? 'Enviar' : 'Grabar audio',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: motion(PfMotion.composerColor),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _tap,
              child: Listener(
                onPointerDown: (_) => setState(() => _pressed = true),
                onPointerUp: (_) => setState(() => _pressed = false),
                onPointerCancel: (_) => setState(() => _pressed = false),
                child: AnimatedScale(
                  scale: _pressed ? 0.88 : 1,
                  duration: motion(const Duration(milliseconds: 100)),
                  curve: Curves.easeOut,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: motion(PfMotion.composerMorph),
                          switchInCurve: PfMotion.overshoot,
                          switchOutCurve: PfMotion.exit,
                          transitionBuilder: (child, a) => RotationTransition(
                            turns: Tween<double>(
                              begin: -0.25,
                              end: 0,
                            ).animate(a),
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.4,
                                end: 1,
                              ).animate(a),
                              child: child,
                            ),
                          ),
                          child: Icon(
                            widget.hasText ? Icons.send : Icons.mic,
                            key: ValueKey(widget.hasText),
                            size: 22,
                            color: ink,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _takeoff,
                          builder: (context, _) {
                            final t = Curves.easeIn.transform(_takeoff.value);
                            if (!_takeoff.isAnimating) {
                              return const SizedBox.shrink();
                            }
                            return Opacity(
                              opacity: 1 - t,
                              child: Transform.translate(
                                offset: Offset(20 * t, -20 * t),
                                child: Transform.rotate(
                                  angle: -12 * 3.14159265 / 180 * t,
                                  child: Transform.scale(
                                    scale: 1 - 0.4 * t,
                                    child: Icon(
                                      Icons.send,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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
