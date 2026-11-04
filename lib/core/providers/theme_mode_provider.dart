import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/providers/storage_providers.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_mode_provider.g.dart';

/// Tema leído de prefs antes de `runApp` (override en main) para que el primer
/// frame ya use el modo guardado, sin parpadeo. Por defecto `system`.
final initialThemeModeProvider = Provider<ThemeMode>(
  (ref) => ThemeMode.system,
  name: 'initialThemeModeProvider',
);

/// Lee el modo guardado (SharedPreferences ya está en caché tras esto).
Future<ThemeMode> readSavedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 2),
    );
    return ThemeModeController._parse(prefs.getString(StorageKeys.themeMode)) ??
        ThemeMode.system;
  } catch (_) {
    return ThemeMode.system;
  }
}

/// Tema elegido por el usuario (light | dark | system), persistido en LocalStorage.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() {
    final initial = ref.read(initialThemeModeProvider);
    _load();
    return initial;
  }

  Future<void> _load() async {
    final storage = await ref.read(localStorageProvider.future);
    final saved = await storage.getString(StorageKeys.themeMode);
    final mode = _parse(saved);
    if (mode != null && mode != state) state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final storage = await ref.read(localStorageProvider.future);
    await storage.setString(StorageKeys.themeMode, mode.name);
  }

  static ThemeMode? _parse(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}
