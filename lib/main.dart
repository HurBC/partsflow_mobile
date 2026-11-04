import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/app.dart';
import 'package:partsflow_mobile/core/media/media_cache_purge.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: PartsFlow()));
  _schedulePurge();
}

/// Purga de temporales fuera del primer frame: tras pintarlo y con un retraso
/// extra; todo es I/O asíncrono (no bloquea la UI) y los errores se ignoran.
void _schedulePurge() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>.delayed(const Duration(seconds: 10), () async {
      try {
        final Directory tmp = await getTemporaryDirectory();
        await purgeMediaCache(tmp);
      } catch (_) {}
    });
  });
}
