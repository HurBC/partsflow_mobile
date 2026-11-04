import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:partsflow_mobile/core/realtime/background_closer.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/rt_latency.dart';
import 'package:partsflow_mobile/core/utils/pf_log.dart';

/// Dos sockets (`chat-list` y `clients`) del subsidiary, con reconexión con
/// backoff (3 s → 30 s con jitter) y reconexión al volver a primer plano.
/// Solo recibe: nunca envía mensajes.
class RealtimeSession with WidgetsBindingObserver {
  RealtimeSession({
    required this.baseUrl,
    required this.origin,
    required this.subsidiaryId,
    required this.onEvent,
    required this.onConnectedChanged,
  });

  final String baseUrl;
  final String origin;
  final String subsidiaryId;
  final void Function(RealtimeEvent) onEvent;

  /// true cuando AMBOS sockets (`chat-list` y `clients`) están abiertos.
  final void Function(bool) onConnectedChanged;

  late final List<_Channel> _channels;
  bool _disposed = false;
  bool _foreground = true;
  DateTime? _pausedAt;
  bool _healthy = false;
  late final BackgroundCloser _closer = BackgroundCloser(onClose: _suspend);

  void start() {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    _channels = [
      _Channel(this, '${base}chat-list/$subsidiaryId/', primary: true),
      _Channel(this, '${base}clients/$subsidiaryId/'),
    ];
    WidgetsBinding.instance.addObserver(this);
    for (final c in _channels) {
      c.connect();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    final fg = state == AppLifecycleState.resumed;
    if (!fg) {
      _pausedAt ??= DateTime.now();
      _foreground = false;
      // Tras 45 s en background se cierran los sockets (sin frames ni parseo).
      _closer.onBackground();
      return;
    }
    _closer.onForeground();
    final away = _pausedAt == null
        ? Duration.zero
        : DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    _foreground = true;
    // Tras un rato en segundo plano el socket puede estar muerto sin avisar.
    final stale = away > const Duration(seconds: 15);
    for (final c in _channels) {
      c.reconnectNow(force: stale);
    }
  }

  void _suspend() {
    if (_disposed || _foreground) return;
    _log('background: cerrando sockets');
    for (final c in _channels) {
      c.suspend();
    }
  }

  void _reportConnected() {
    if (_disposed) return;
    final h = _channels.every((c) => c.connected);
    if (h == _healthy) return;
    _healthy = h;
    onConnectedChanged(h);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _channels) {
      c.close();
    }
  }

  void _log(String msg) {
    if (pfDebugLog) {
      pfLog('[realtime] $msg');
    } else if (kDebugMode) {
      debugPrint('[realtime] $msg');
    }
  }
}

class _Channel {
  _Channel(this._s, this.url, {this.primary = false});

  final RealtimeSession _s;
  final String url;
  final bool primary;

  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  int _attempts = 0;
  int _gen = 0;
  bool _connecting = false;
  bool _closed = false;

  bool get connected => _ws != null;

  String get _name => primary ? 'chat-list' : 'clients';

  Future<void> connect() async {
    if (_closed || _connecting || _ws != null) return;
    _connecting = true;
    final gen = ++_gen;
    _retry?.cancel();
    WebSocket ws;
    try {
      ws = await WebSocket.connect(
        url,
        headers: {'Origin': _s.origin},
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      _connecting = false;
      if (gen != _gen) return;
      _s._log('$_name: no conectó ($e)');
      _scheduleRetry();
      return;
    }
    _connecting = false;
    if (_closed || gen != _gen) {
      unawaited(ws.close());
      return;
    }
    ws.pingInterval = const Duration(seconds: 25);
    _ws = ws;
    _attempts = 0;
    _s._log('$_name: conectado');
    _s._reportConnected();
    _s.onEvent(const RealtimeResync());
    _sub = ws.listen(
      (data) {
        final e = parseRealtimeFrame(data);
        if (pfDebugLog && e != null) {
          pfLog('rt ${e.runtimeType}');
          final now = DateTime.now().millisecondsSinceEpoch;
          if (e is RealtimeNewMessages) {
            logRtLatency('new_message', e.items, now);
          } else if (e is RealtimeMessageUpdates) {
            logRtLatency('message_update', e.items, now);
          } else if (e is RealtimeStatusUpdates) {
            logRtLatency('status_update', e.items, now);
          }
        }
        if (e != null && !_closed) _s.onEvent(e);
      },
      onDone: () => _lost(ws),
      onError: (_) => _lost(ws),
      cancelOnError: true,
    );
  }

  void _lost(WebSocket ws) {
    if (!identical(ws, _ws)) return;
    _s._log('$_name: caído');
    _ws = null;
    _sub = null;
    if (!_closed) _s._reportConnected();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    // En segundo plano no se reintenta: al volver a primer plano reconecta.
    if (_closed || !_s._foreground) return;
    _retry?.cancel();
    final base = min(30.0, 3.0 * pow(2, _attempts));
    _attempts++;
    final jitter = 0.8 + Random().nextDouble() * 0.4;
    _retry = Timer(Duration(milliseconds: (base * jitter * 1000).round()), () {
      connect();
    });
  }

  /// Al volver a primer plano: reconecta de inmediato lo caído y, con [force],
  /// también lo que parece abierto.
  void reconnectNow({required bool force}) {
    if (_closed) return;
    if (_ws != null && !force) return;
    _retry?.cancel();
    _attempts = 0;
    _gen++; // invalida un intento de conexión en curso
    _connecting = false;
    _detach();
    connect();
  }

  void _detach() {
    final ws = _ws;
    _ws = null;
    unawaited(_sub?.cancel());
    _sub = null;
    if (ws != null) {
      unawaited(ws.close());
      if (!_closed) _s._reportConnected();
    }
  }

  /// Cierre por inactividad en background: sin reintentos; reconecta con
  /// [reconnectNow] al volver.
  void suspend() {
    if (_closed) return;
    _retry?.cancel();
    _attempts = 0;
    _gen++;
    _connecting = false;
    _detach();
  }

  void close() {
    _closed = true;
    _gen++;
    _retry?.cancel();
    final ws = _ws;
    _ws = null;
    unawaited(_sub?.cancel());
    _sub = null;
    if (ws != null) unawaited(ws.close());
  }
}
