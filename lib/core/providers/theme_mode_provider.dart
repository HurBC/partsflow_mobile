import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/providers/storage_providers.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_provider.g.dart';

/// Tema elegido por el usuario (light | dark | system), persistido en LocalStorage.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
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
