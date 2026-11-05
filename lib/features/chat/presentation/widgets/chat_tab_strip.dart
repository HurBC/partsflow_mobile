import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';

const _slideDuration = Duration(milliseconds: 320);
const _pillHeight = 36.0;

/// Pestañas de la lista con un indicador (píldora primaria) que se desliza
/// entre ellas. Las píldoras tienen fondo transparente; el indicador va debajo.
class ChatTabStrip extends StatefulWidget {
  const ChatTabStrip({
    super.key,
    required this.tab,
    required this.assignedEnabled,
    required this.onTab,
  });

  final ChatTab tab;
  final bool assignedEnabled;
  final ValueChanged<ChatTab> onTab;

  @override
  State<ChatTabStrip> createState() => _ChatTabStripState();
}

class _ChatTabStripState extends State<ChatTabStrip>
    with SingleTickerProviderStateMixin {
  final _rowKey = GlobalKey();
  final _pillKeys = {for (final t in ChatTab.values) t: GlobalKey()};
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _slideDuration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutBack,
  );
  Rect? _from;
  Rect? _to;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure(animate: false);
  }

  @override
  void didUpdateWidget(ChatTabStrip old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) _scheduleMeasure(animate: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Rect? get _current {
    final to = _to;
    if (to == null) return null;
    final from = _from ?? to;
    return Rect.lerp(from, to, _c.isAnimating ? _curve.value : 1);
  }

  void _scheduleMeasure({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final row = _rowKey.currentContext?.findRenderObject();
      final pill = _pillKeys[widget.tab]?.currentContext?.findRenderObject();
      if (row is! RenderBox || pill is! RenderBox || !row.attached) return;
      if (!pill.attached || !row.hasSize || !pill.hasSize) return;
      final target = pill.localToGlobal(Offset.zero, ancestor: row) & pill.size;
      final from = _current;
      // Sin cambio real de rect no hay setState (evita bucles con el notifier).
      if (_to == target && !animate) return;
      setState(() {
        _from = from ?? target;
        _to = target;
      });
      if (animate &&
          from != null &&
          from != target &&
          !MediaQuery.disableAnimationsOf(context)) {
        _c.forward(from: 0);
      } else {
        _c.value = 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasIndicator = _to != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          if (hasIndicator)
            Positioned(
              left: 0,
              top: 6,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final r = _current!;
                  return Transform.translate(
                    offset: Offset(r.left, 0),
                    child: SizedBox(
                      key: const ValueKey('chat-tab-indicator'),
                      width: r.width < 0 ? 0 : r.width,
                      height: _pillHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              // Cambió el layout (etiquetas, habilitadas, escala de texto).
              _scheduleMeasure(animate: false);
              return true;
            },
            child: SizeChangedLayoutNotifier(
              child: Row(
                key: _rowKey,
                children: [
                  for (final t in ChatTab.values) ...[
                    if (t != ChatTab.values.first) const SizedBox(width: 8),
                    _TabPill(
                      key: _pillKeys[t],
                      label: t.label,
                      selected: t == widget.tab,
                      enabled: t != ChatTab.assigned || widget.assignedEnabled,
                      fallbackFill: !hasIndicator,
                      onTap: () => widget.onTab(t),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.fallbackFill,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;

  /// Antes de medir el indicador, la seleccionada se pinta con su propio fondo.
  final bool fallbackFill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Opacity(
                opacity: enabled ? 1 : 0.45,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _pillHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected && fallbackFill ? primary : null,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? Colors.transparent : pf.border,
                      width: 1.5,
                    ),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight
                          .w600, // constante: el ancho no depende de la selección
                      color: selected ? onPrimary : pf.textMid,
                    ),
                    child: Text(label),
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
