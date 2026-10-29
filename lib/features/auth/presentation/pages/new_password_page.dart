import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:partsflow_mobile/features/auth/presentation/widgets/password_rules.dart';

class NewPasswordPage extends StatelessWidget {
  const NewPasswordPage({
    super.key,
    required this.email,
    required this.session,
  });

  final String email;
  final String session;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: _NewPasswordView(email: email, session: session),
    );
  }
}

class _NewPasswordView extends ConsumerStatefulWidget {
  const _NewPasswordView({required this.email, required this.session});

  final String email;
  final String session;

  @override
  ConsumerState<_NewPasswordView> createState() => _NewPasswordViewState();
}

class _NewPasswordViewState extends ConsumerState<_NewPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();

  bool _loading = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final result = await ref
        .read(authControllerProvider.notifier)
        .setPermanentPassword(
          email: widget.email,
          password: _password.text,
          session: widget.session,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result case Err(failure: final failure)) {
      setState(() => _error = newPasswordErrorMessage(failure));
    }
    // Si salió bien, authState se invalida y el router lleva a /chat.
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final autovalidate = _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return AuthScaffold(
      hero: Padding(
        padding: EdgeInsets.fromLTRB(20, top + 8, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.translate(
              offset: const Offset(-10, 0),
              child: IconButton(
                tooltip: 'Volver al inicio de sesión',
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.login),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: const Text(
                      'Crea tu contraseña',
                      style: TextStyle(
                        fontSize: 28,
                        height: 34 / 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Entraste con una contraseña temporal. Crea una nueva para seguir.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 22 / 15,
                      color: Color(0xFFC9CDF0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFC9CDF0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      form: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthPasswordField(
                  label: 'Nueva contraseña',
                  controller: _password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  autovalidateMode: autovalidate,
                  onChanged: (_) => setState(() {}),
                  validator: (v) => passwordMeetsRules(v ?? '')
                      ? null
                      : 'La contraseña no cumple los requisitos',
                  onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                PasswordRulesList(password: _password.text),
                const SizedBox(height: 16),
                AuthPasswordField(
                  label: 'Repite la contraseña',
                  controller: _confirm,
                  hint: 'Escríbela de nuevo',
                  focusNode: _confirmFocus,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  autovalidateMode: autovalidate,
                  validator: (v) => v == _password.text
                      ? null
                      : 'Las contraseñas no coinciden',
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBanner(_error!),
                ],
                const Spacer(),
                const SizedBox(height: 16),
                AuthPrimaryButton(
                  label: 'Guardar y entrar',
                  loadingLabel: 'Guardando…',
                  loading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
