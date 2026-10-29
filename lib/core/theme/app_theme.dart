import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/app_color_schema.dart';
import 'package:partsflow_mobile/core/theme/app_text_schema.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';

abstract class AppTheme {
  static final light = _buildTheme(AppColorSchema.light, PfColors.light);
  static final dark = _buildTheme(AppColorSchema.dark, PfColors.dark);

  static ThemeData _buildTheme(ColorScheme scheme, PfColors pf) {
    final textTheme = AppTextTheme.base.apply(
      bodyColor: pf.text,
      displayColor: pf.text,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextTheme.fontFamily,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: pf.bg,
      dividerColor: pf.divider,
      extensions: [pf],

      appBarTheme: AppBarTheme(
        backgroundColor: pf.surface,
        foregroundColor: pf.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pf.surface,
        hintStyle: TextStyle(color: pf.placeholder),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pf.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pf.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: pf.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: pf.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: pf.text,
        contentTextStyle: TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 14,
          color: pf.bg,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: pf.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: pf.indicator,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AppTextTheme.fontFamily,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? pf.link : pf.text2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 24, color: selected ? pf.link : pf.text2);
        }),
      ),
    );
  }
}
