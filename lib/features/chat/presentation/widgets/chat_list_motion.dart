import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';

const _riseSlide = Duration(milliseconds: 340);
const _riseFlash = Duration(milliseconds: 1600);
const _popDuration = Duration(milliseconds: 420);
const _counterDuration = Duration(milliseconds: 260);

/// Cuánto tiempo sigue siendo válido un disparo de "subió" para una fila que
/// se monta tarde (p. ej. el usuario estaba scrolleado y vuelve arriba).
const chatRiseWindow = Duration(seconds: 2);

/// Detecta, con costo O(n) por cambio de la secuencia de ids (no por frame),
/// que un chat llegó a la cima POR ACTIVIDAD NUEVA.
///
/// Guarda la actividad de los ids visibles en la secuencia anterior. Un chat
/// "sube" solo si ya estaba visible (no era la cima) y su actividad es
/// estrictamente posterior a la guardada. Carga inicial (sin snapshot),
/// paginación (cima intacta), cambio de pestaña/búsqueda/filtros (la actividad
/// no cambió o el chat no estaba en el snapshot) no disparan.
class ChatRiseDetector {
  Map<String, DateTime?> _snap = const {};
  String? _head;

  /// Olvida el snapshot (cambio de pestaña/búsqueda/filtros): el siguiente
  /// `update` solo siembra.
  void reset() {
    _snap = const {};
    _head = null;
  }

  /// Registra la nueva secuencia; devuelve el id que subió, o null.
  String? update(List<String> ids, Map<String, Chat> byId) {
    final head = ids.isEmpty ? null : ids.first;
    String? rose;
    if (head != null && _head != null && head != _head) {
      if (_snap.containsKey(head)) {
        final before = _snap[head];
        final chat = byId[head];
        final now = chat?.activityAt;
        // Si la última actividad es un mensaje propio (saliente), no destella.
        final ours = chat?.lastMessage?.isOutbound ?? false;
        if (!ours && before != null && now != null && now.isAfter(before)) {
          rose = head;
        }
      }
    }
    _head = head;
    _snap = {for (final id in ids) id: byId[id]?.activityAt};
    return rose;
  }
}

/// Fila que, con un [token] distinto de 0 nuevo, entra con slide desde arriba
/// (solo transform) y destello de fondo juliaBg -> transparente.
///
/// La estructura del árbol es constante (no remonta el hijo). El estado vive
/// en la fila por ValueKey, así que sobrevive a reordenamientos; un remonte por
/// reciclado solo repite si el token sigue dentro de [chatRiseWindow].
class ChatRowRise extends StatefulWidget {
  const ChatRowRise({super.key, required this.token, required this.child});

  final int token;
  final Widget child;

  @override
  State<ChatRowRise> createState() => _ChatRowRiseState();
}

class _ChatRowRiseState extends State<ChatRowRise>
    with SingleTickerProviderStateMixin {
  static final _slideEnd =
      _riseSlide.inMilliseconds / _riseFlash.inMilliseconds;
  AnimationController? _c;
  Animation<double>? _slide;
  Animation<double>? _flash;
  int _played = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePlay();
  }

  @override
  void didUpdateWidget(ChatRowRise old) {
    super.didUpdateWidget(old);
    _maybePlay();
  }

  void _maybePlay() {
    final t = widget.token;
    if (t == 0 || t == _played) return;
    _played = t;
    if (MediaQuery.disableAnimationsOf(context)) return;
    // Controller perezoso: solo existe si una animación realmente empieza.
    final c = _c ??= AnimationController(vsync: this, duration: _riseFlash);
    _slide ??= CurvedAnimation(
      parent: c,
      curve: Interval(0, _slideEnd, curve: Curves.easeOutCubic),
    );
    _flash ??= CurvedAnimation(parent: c, curve: Curves.easeOut);
    c.forward(from: 0);
    setState(() {}); // pasa de la animación de reposo a la real
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final flashColor = PfColors.of(context).juliaBg;
    // Estructura constante (no remonta el hijo); en reposo es barata porque no
    // hay controller ni listeners: la animación es una constante.
    return AnimatedBuilder(
      animation: c ?? const AlwaysStoppedAnimation(0.0),
      child: widget.child,
      builder: (context, child) {
        final run = c != null && c.isAnimating;
        return Transform.translate(
          offset: Offset(0, run ? -40 * (1 - _slide!.value) : 0),
          child: DecoratedBox(
            key: const ValueKey('chat-row-flash'),
            decoration: BoxDecoration(
              color: flashColor.withValues(
                alpha: run ? (1 - _flash!.value) * flashColor.a : 0,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Cambio de contador/etiqueta con slide-up: el nuevo entra desde abajo y el
/// anterior sale hacia arriba. [value] identifica el contenido.
class SlideUpSwitcher extends StatelessWidget {
  const SlideUpSwitcher({super.key, required this.value, required this.child});

  final Object value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final key = ValueKey(value);
    return AnimatedSwitcher(
      duration: animate ? _counterDuration : Duration.zero,
      transitionBuilder: (c, a) {
        final incoming = c.key == key;
        // El saliente no entra al árbol de semántica (se lee el conteo una vez).
        if (!incoming) c = ExcludeSemantics(child: c);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: Offset(0, incoming ? 0.7 : -0.7),
              end: Offset.zero,
            ).animate(a),
            child: c,
          ),
        );
      },
      child: KeyedSubtree(key: key, child: child),
    );
  }
}

/// Pop (scale 0 -> 1.35 -> 1) cuando [trigger] cambia a un valor mayor.
/// Útil para badges y contadores; no dispara al montarse.
class CountPop extends StatefulWidget {
  const CountPop({
    super.key,
    required this.count,
    required this.child,
    this.peak = 1.35,
    this.fromZero = true,
  });

  final int count;
  final Widget child;
  final double peak;

  /// true: escala 0 -> peak -> 1 (badge que aparece); false: 1 -> peak -> 1.
  final bool fromZero;

  @override
  State<CountPop> createState() => _CountPopState();
}

class _CountPopState extends State<CountPop>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _scale;

  @override
  void didUpdateWidget(CountPop old) {
    super.didUpdateWidget(old);
    if (widget.count > old.count && !MediaQuery.disableAnimationsOf(context)) {
      final c = _c ??= AnimationController(vsync: this, duration: _popDuration);
      _scale ??= TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: widget.fromZero ? 0.0 : 1.0,
            end: widget.peak,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 55,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: widget.peak,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 45,
        ),
      ]).animate(c);
      c.forward(from: 0);
      setState(() {});
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
    return AnimatedBuilder(
      animation: c ?? const AlwaysStoppedAnimation(0.0),
      child: widget.child,
      builder: (context, child) => Transform.scale(
        scale: c != null && c.isAnimating ? _scale!.value : 1,
        child: child,
      ),
    );
  }
}
