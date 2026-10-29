import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/config/app_info.dart';
import 'package:partsflow_mobile/core/providers/theme_mode_provider.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/current_user.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pf = PfColors.of(context);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 16,
              16,
              16,
            ),
            decoration: BoxDecoration(
              color: pf.surface,
              border: Border(bottom: BorderSide(color: pf.divider)),
            ),
            child: Semantics(
              header: true,
              child: Text(
                'Perfil',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (user != null) ...[
                  _UserCard(user: user),
                  const SizedBox(height: 10),
                  _Section(
                    title: 'Tu cuenta',
                    children: [
                      _InfoRow(label: 'Proveedor', value: user.supplierName),
                      _InfoRow(
                        label: 'Sucursal',
                        value: user.subsidiaryName,
                        last: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                const _ThemeSection(),
                const SizedBox(height: 10),
                _Section(
                  children: [
                    _InfoRow(
                      label: 'Versión',
                      value: appEnv.isEmpty
                          ? appVersion
                          : '$appVersion · $appEnv',
                      muted: true,
                      last: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _LogoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final CurrentUser user;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pf.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF181D84),
              shape: BoxShape.circle,
            ),
            child: Text(
              user.initials,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? user.email : user.fullName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: pf.text,
                  ),
                ),
                if (user.fullName.isNotEmpty)
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: pf.text2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: pf.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pf.text2,
                  ),
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.last = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool last;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: pf.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: pf.textMid)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15,
                fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
                color: muted ? pf.text2 : pf.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pf = PfColors.of(context);
    final mode = ref.watch(themeModeControllerProvider);
    const options = [
      (ThemeMode.light, 'Claro'),
      (ThemeMode.dark, 'Oscuro'),
      (ThemeMode.system, 'Sistema'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        color: pf.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            child: Semantics(
              header: true,
              child: Text(
                'Apariencia',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pf.text2,
                ),
              ),
            ),
          ),
          Semantics(
            container: true,
            label: 'Tema',
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: pf.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  for (final (value, label) in options)
                    Expanded(
                      child: _ThemeOption(
                        label: label,
                        selected: mode == value,
                        onTap: () => ref
                            .read(themeModeControllerProvider.notifier)
                            .setMode(value),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? pf.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x140F1222),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? pf.link : pf.textMid,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a ingresar con tu correo y contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: PfColors.of(ctx).errIcon,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pf = PfColors.of(context);

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: () => _confirm(context, ref),
        style: OutlinedButton.styleFrom(
          backgroundColor: pf.surface,
          foregroundColor: pf.errIcon,
          side: BorderSide(
            color: pf.errIcon.withValues(alpha: 0.45),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('Cerrar sesión'),
      ),
    );
  }
}
