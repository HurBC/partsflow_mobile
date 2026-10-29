import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/providers/theme_mode_provider.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/router/app_router.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';

class PartsFlow extends ConsumerWidget {
  const PartsFlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene viva la conexión de tiempo real (conecta tras el login).
    ref.read(realtimeProvider);
    return MaterialApp.router(
      title: "Partsflow",
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeControllerProvider),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
