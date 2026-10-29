import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';

/// Fondo oscuro de las pantallas de acceso. Usar dentro de `Theme(data: AppTheme.dark)`.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.hero, required this.form});

  final Widget hero;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: pf.bg,
        body: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: PfColors.heroGradient,
                ),
                child: hero,
              ),
            ),
            SliverFillRemaining(hasScrollBody: false, child: form),
          ],
        ),
      ),
    );
  }
}

class AuthLabeledField extends StatelessWidget {
  const AuthLabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration authInputDecoration(
  BuildContext context, {
  String? hint,
  Widget? suffix,
  bool focused = false,
}) {
  final pf = PfColors.of(context);
  OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: pf.placeholder, fontSize: 16),
    filled: true,
    fillColor: pf.surface,
    suffixIcon: suffix,
    errorStyle: TextStyle(color: pf.errFg, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: border(focused ? pf.mint : pf.border),
    border: border(pf.border),
    focusedBorder: border(pf.mint),
    errorBorder: border(pf.errIcon),
    focusedErrorBorder: border(pf.errIcon),
  );
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.autovalidateMode,
    this.focusNode,
    this.onChanged,
    this.obscureText = false,
    this.suffix,
    this.autocorrect = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final bool obscureText;
  final Widget? suffix;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return AuthLabeledField(
      label: label,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        autocorrect: autocorrect,
        enableSuggestions: autocorrect,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        autovalidateMode: autovalidateMode,
        cursorColor: pf.mint,
        style: TextStyle(fontSize: 16, color: pf.text),
        decoration: authInputDecoration(context, hint: hint, suffix: suffix),
      ),
    );
  }
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
  });

  final FocusNode? focusNode;
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return AuthTextField(
      label: widget.label,
      controller: widget.controller,
      focusNode: widget.focusNode,
      hint: widget.hint,
      obscureText: !_visible,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      autovalidateMode: widget.autovalidateMode,
      suffix: IconButton(
        tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: Icon(
          _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: pf.text2,
        ),
        onPressed: () => setState(() => _visible = !_visible),
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: pf.errBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, size: 18, color: pf.errIcon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: pf.errFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final String loadingLabel;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: pf.mint,
          foregroundColor: pf.onMint,
          disabledBackgroundColor: pf.mint,
          disabledForegroundColor: pf.onMint,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: pf.onMint,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(loadingLabel),
                ],
              )
            : Text(label),
      ),
    );
  }
}
