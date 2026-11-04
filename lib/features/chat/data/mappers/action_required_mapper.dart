import 'package:partsflow_mobile/core/utils/json_utils.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/action_required_counts.dart';

/// Tolerante: claves ausentes o con elementos inválidos se ignoran.
ActionRequiredCounts actionRequiredFromJson(Object? json) {
  final m = asMap(json);
  if (m == null) return ActionRequiredCounts.empty;
  List<int> ids(String k) => [for (final v in asList(m[k])) ?asInt(v)];
  return ActionRequiredCounts(
    toQuoteOrders: ids('to_quote_orders'),
    optionsAcceptedOrders: ids('options_accepted_orders'),
    importantClients: [
      for (final v in asList(m['important_clients'])) ?nonEmpty(asStr(v)),
    ],
  );
}
