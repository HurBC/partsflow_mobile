import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/action_required_counts.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';

/// Tarjetas del resumen (BO: ChatSummaryCards).
enum ActionCard { importantClients, toQuote, optionsAccepted }

class ActionRequiredState {
  const ActionRequiredState({
    this.counts = ActionRequiredCounts.empty,
    this.dismissed = const {},
  });

  final ActionRequiredCounts counts;

  /// Descartadas en esta sesión (no se persisten).
  final Set<ActionCard> dismissed;

  int countOf(ActionCard c) => switch (c) {
    ActionCard.importantClients => counts.importantClients.length,
    ActionCard.toQuote => counts.toQuoteOrders.length,
    ActionCard.optionsAccepted => counts.optionsAcceptedOrders.length,
  };

  /// Tarjetas a mostrar: con elementos y no descartadas (en orden del BO).
  List<ActionCard> get visible => [
    for (final c in ActionCard.values)
      if (!dismissed.contains(c) && countOf(c) > 0) c,
  ];

  @override
  bool operator ==(Object other) =>
      other is ActionRequiredState &&
      other.counts == counts &&
      other.dismissed.length == dismissed.length &&
      other.dismissed.containsAll(dismissed);

  @override
  int get hashCode => Object.hash(counts, Object.hashAllUnordered(dismissed));
}

/// Contadores de acción requerida. Se cargan al montar, con pull-to-refresh y
/// con el watchdog del listado ([refresh] con `force: false` se limita a una
/// consulta por [minGap]); nunca por evento realtime.
class ActionRequiredController extends Notifier<ActionRequiredState> {
  static const minGap = Duration(seconds: 60);

  DateTime? _last;
  bool _loading = false;
  int _gen = 0;

  @override
  ActionRequiredState build() {
    // Al cambiar la sesión se descarta todo (incluidos los descartes).
    ref.watch(sessionActiveProvider);
    _last = null;
    _loading = false;
    _gen++;
    Future.microtask(() {
      if (ref.mounted) refresh(force: true);
    });
    return const ActionRequiredState();
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    final last = _last;
    if (!force && last != null && DateTime.now().difference(last) < minGap) {
      return;
    }
    _loading = true;
    final gen = _gen;
    try {
      final r = await ref.read(chatRepositoryProvider).actionRequiredCounts();
      // Sesión distinta a la que pidió: el resultado no le corresponde.
      if (!ref.mounted || gen != _gen) return;
      // Error: se conservan los últimos valores (el resumen es accesorio).
      if (r case Ok(:final value)) {
        _last = DateTime.now();
        if (value != state.counts) {
          state = ActionRequiredState(
            counts: value,
            dismissed: state.dismissed,
          );
        }
      }
    } finally {
      if (gen == _gen) _loading = false;
    }
  }

  void dismiss(ActionCard card) {
    state = ActionRequiredState(
      counts: state.counts,
      dismissed: {...state.dismissed, card},
    );
  }
}

final actionRequiredProvider =
    NotifierProvider<ActionRequiredController, ActionRequiredState>(
      ActionRequiredController.new,
    );
