import 'package:flutter/material.dart';

/// Tokens de marca que no caben en [ColorScheme].
/// Acceso: `PfColors.of(context)`.
@immutable
class PfColors extends ThemeExtension<PfColors> {
  const PfColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.divider,
    required this.text,
    required this.text2,
    required this.textMid,
    required this.placeholder,
    required this.link,
    required this.mint,
    required this.onMint,
    required this.indicator,
    required this.juliaBg,
    required this.juliaFg,
    required this.warnBg,
    required this.warnFg,
    required this.errBg,
    required this.errFg,
    required this.errIcon,
    required this.bubbleIn,
    required this.bubbleOut,
    required this.bubbleOutText,
    required this.bubbleOutTime,
    required this.bubbleJulia,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color divider;
  final Color text;
  final Color text2;
  final Color textMid;
  final Color placeholder;
  final Color link;

  /// Menta de marca: SOLO como relleno; el texto encima usa [onMint].
  final Color mint;
  final Color onMint;
  final Color indicator;
  final Color juliaBg;
  final Color juliaFg;
  final Color warnBg;
  final Color warnFg;
  final Color errBg;
  final Color errFg;
  final Color errIcon;
  final Color bubbleIn;
  final Color bubbleOut;
  final Color bubbleOutText;
  final Color bubbleOutTime;
  final Color bubbleJulia;

  // Etapas del pedido (puntos; el texto va en color neutro).
  static const stagePorCotizar = Color(0xFF9333EA);
  static const stageCotizacionEnviada = Color(0xFF2563EB);
  static const stagePosibleVenta = Color(0xFF0D9488);
  static const stageVentaPorGestionar = Color(0xFF16A34A);
  static const stageDevolucion = Color(0xFFEA580C);

  // Degradado del hero de las pantallas de acceso (170 grados).
  static const heroGradient = LinearGradient(
    begin: Alignment(-0.17, -1),
    end: Alignment(0.17, 1),
    colors: [
      Color(0xFF181D84),
      Color(0xFF1A2494),
      Color(0xFF142A78),
      Color(0xFF0E1133),
    ],
    stops: [0, 0.38, 0.66, 1],
  );

  static const light = PfColors(
    bg: Color(0xFFF3F4F9),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F4F9),
    border: Color(0xFFD3D6E4),
    divider: Color(0xFFECEEF5),
    text: Color(0xFF0F1222),
    text2: Color(0xFF5B6275),
    textMid: Color(0xFF2B3045),
    placeholder: Color(0xFF5B6275),
    link: Color(0xFF181D84),
    mint: Color(0xFF43DBAD),
    onMint: Color(0xFF181D84),
    indicator: Color(0xFFE4E6F7),
    juliaBg: Color(0xFFDCF7EE),
    juliaFg: Color(0xFF0B5A4F),
    warnBg: Color(0xFFFFF4D6),
    warnFg: Color(0xFF7A4B00),
    errBg: Color(0xFFFDE7E7),
    errFg: Color(0xFF9F1D1D),
    errIcon: Color(0xFFB42318),
    bubbleIn: Color(0xFFFFFFFF),
    bubbleOut: Color(0xFF181D84),
    bubbleOutText: Color(0xFFFFFFFF),
    bubbleOutTime: Color(0xFFC9CDF0),
    bubbleJulia: Color(0xFFFFFFFF),
  );

  // Valores de bg/surface/border/texto/error vienen de la SPEC; el resto
  // (julia, warn, burbujas, indicador) son derivados propios para fondo oscuro.
  static const dark = PfColors(
    bg: Color(0xFF0E1133),
    surface: Color(0xFF171B45),
    surface2: Color(0xFF1F2456),
    border: Color(0xFF2C3270),
    divider: Color(0xFF232859),
    text: Color(0xFFEEF0FF),
    text2: Color(0xFFA9AFDA),
    textMid: Color(0xFFCFD3F5),
    placeholder: Color(0xFF8B91C7),
    link: Color(0xFF43DBAD),
    mint: Color(0xFF43DBAD),
    onMint: Color(0xFF0E1133),
    indicator: Color(0xFF2C3270),
    juliaBg: Color(0xFF0F3D3A),
    juliaFg: Color(0xFF9AF0D6),
    warnBg: Color(0xFF3A2F10),
    warnFg: Color(0xFFFFD98A),
    errBg: Color(0xFF3A1D33),
    errFg: Color(0xFFFFC9CC),
    errIcon: Color(0xFFFF9EA2),
    bubbleIn: Color(0xFF1F2456),
    bubbleOut: Color(0xFF2A32A8),
    bubbleOutText: Color(0xFFFFFFFF),
    bubbleOutTime: Color(0xFFC9CDF0),
    bubbleJulia: Color(0xFF1A2350),
  );

  static PfColors of(BuildContext context) =>
      Theme.of(context).extension<PfColors>()!;

  @override
  PfColors copyWith() => this;

  @override
  PfColors lerp(ThemeExtension<PfColors>? other, double t) {
    if (other is! PfColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PfColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      border: l(border, other.border),
      divider: l(divider, other.divider),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      textMid: l(textMid, other.textMid),
      placeholder: l(placeholder, other.placeholder),
      link: l(link, other.link),
      mint: l(mint, other.mint),
      onMint: l(onMint, other.onMint),
      indicator: l(indicator, other.indicator),
      juliaBg: l(juliaBg, other.juliaBg),
      juliaFg: l(juliaFg, other.juliaFg),
      warnBg: l(warnBg, other.warnBg),
      warnFg: l(warnFg, other.warnFg),
      errBg: l(errBg, other.errBg),
      errFg: l(errFg, other.errFg),
      errIcon: l(errIcon, other.errIcon),
      bubbleIn: l(bubbleIn, other.bubbleIn),
      bubbleOut: l(bubbleOut, other.bubbleOut),
      bubbleOutText: l(bubbleOutText, other.bubbleOutText),
      bubbleOutTime: l(bubbleOutTime, other.bubbleOutTime),
      bubbleJulia: l(bubbleJulia, other.bubbleJulia),
    );
  }
}
