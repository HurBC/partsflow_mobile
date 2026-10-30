import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/providers/storage_providers.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/login_outcome.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/auth/presentation/widgets/auth_widgets.dart';

/// Las pantallas de acceso siempre usan la paleta oscura.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(data: AppTheme.dark, child: const _LoginView());
  }
}

class _LoginView extends ConsumerStatefulWidget {
  const _LoginView();

  @override
  ConsumerState<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _showSessionExpiredNotice();
  }

  Future<void> _showSessionExpiredNotice() async {
    final storage = ref.read(secureStorageProvider);
    final flag = await storage.read(StorageKeys.sessionExpired);
    if (flag == null) return;
    await storage.delete(StorageKeys.sessionExpired);
    if (!mounted) return;
    setState(() => _error = 'Tu sesión expiró, vuelve a ingresar');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
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
        .login(_email.text, _password.text);

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Ok(value: final NewPasswordRequired outcome):
        context.push(
          AppRoutes.newPassword,
          extra: (email: outcome.email, session: outcome.session),
        );
      case Ok():
        break; // el router redirige al invalidarse authState
      case Err(failure: final failure):
        setState(() => _error = loginErrorMessage(failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final autovalidate = _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return AuthScaffold(
      hero: Padding(
        padding: EdgeInsets.fromLTRB(28, top + 24, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/partsflow_logo_circular.png',
                    width: 38,
                    height: 38,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Partsflow',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.23,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Semantics(
              header: true,
              child: const Text(
                'Tus ventas por WhatsApp, en el bolsillo.',
                style: TextStyle(
                  fontSize: 28,
                  height: 35 / 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.56,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Responde, cotiza y mueve pedidos desde donde estés.',
              style: TextStyle(
                fontSize: 15,
                height: 22 / 15,
                color: Color(0xFFC9CDF0),
              ),
            ),
          ],
        ),
      ),
      form: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: 'Correo electrónico',
                  controller: _email,
                  hint: 'correo@empresa.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  autovalidateMode: autovalidate,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tu correo'
                      : null,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  label: 'Contraseña',
                  controller: _password,
                  hint: 'Tu contraseña',
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  autovalidateMode: autovalidate,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                  onFieldSubmitted: (_) => _submit(),
                  focusNode: _passwordFocus,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBanner(_error!),
                ],
                const SizedBox(height: 22),
                AuthPrimaryButton(
                  label: 'Iniciar sesión',
                  loadingLabel: 'Iniciando sesión…',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: pf.link,
                      minimumSize: const Size(44, 44),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Recupérala desde el Backoffice por ahora.',
                        ),
                      ),
                    ),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tu sucursal se asigna según tu cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: pf.text2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
