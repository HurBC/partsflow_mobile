import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/ui/toast/pf_toast.dart';

/// Colores del aviso: la cápsula usa el tema inverso (fondo = pf.text).
@immutable
class PfToastPalette {
  const PfToastPalette({
    required this.capsule,
    required this.title,
    required this.body,
    required this.actionBg,
    required this.actionFg,
    required this.chipBg,
    required this.chipFg,
    required this.bar,
  });

  final Color capsule;
  final Color title;
  final Color body;
  final Color actionBg;
  final Color actionFg;
  final Color chipBg;
  final Color chipFg;
  final Color bar;

  static PfToastPalette of(BuildContext context, PfToastKind kind) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pf = PfColors.of(context);
    // Texto secundario del tema inverso.
    final body = dark ? PfColors.light.text2 : PfColors.dark.text2;
    final actionBg = dark ? PfColors.light.onMint : pf.mint;
    final actionFg = dark ? pf.text : pf.onMint;

    late final Color chipBg, chipFg, bar;
    switch (kind) {
      case PfToastKind.success:
      case PfToastKind.julia:
        chipBg = pf.juliaBg;
        chipFg = pf.juliaFg;
        bar = dark ? _barSuccessDark : pf.mint;
      case PfToastKind.info:
      case PfToastKind.loading:
        chipBg = dark ? pf.surface2 : pf.indicator;
        chipFg = dark ? pf.text2 : pf.link;
        bar = dark ? _barInfoDark : PfColors.dark.text2;
      case PfToastKind.warning:
        chipBg = pf.warnBg;
        chipFg = pf.warnFg;
        bar = dark ? _barWarnDark : PfColors.dark.warnFg;
      case PfToastKind.error:
        chipBg = pf.errBg;
        chipFg = pf.errIcon;
        bar = dark ? _barErrDark : PfColors.dark.errIcon;
    }
    return PfToastPalette(
      capsule: pf.text,
      title: pf.bg,
      body: body,
      actionBg: actionBg,
      actionFg: actionFg,
      chipBg: chipBg,
      chipFg: chipFg,
      bar: bar,
    );
  }

  // Barras en tema oscuro (sobre cápsula clara).
  static const _barSuccessDark = Color(0xFF0B5A4F);
  static const _barInfoDark = Color(0xFF181D84);
  static const _barWarnDark = Color(0xFF7A4B00);
  static const _barErrDark = Color(0xFFB42318);
}
