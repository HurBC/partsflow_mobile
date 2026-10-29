import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';

class PasswordRule {
  const PasswordRule(this.label, this.test);

  final String label;
  final bool Function(String) test;
}

final passwordRules = <PasswordRule>[
  PasswordRule('Al menos 8 caracteres', (p) => p.length >= 8),
  PasswordRule(
    'Una mayúscula y una minúscula',
    (p) =>
        RegExp('[A-ZÁÉÍÓÚÑÜ]').hasMatch(p) &&
        RegExp('[a-záéíóúñü]').hasMatch(p),
  ),
  PasswordRule('Al menos un número', (p) => RegExp('[0-9]').hasMatch(p)),
  PasswordRule(
    'Al menos un símbolo (por ejemplo ! o #)',
    (p) => RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÑÜáéíóúñü\s]').hasMatch(p),
  ),
];

bool passwordMeetsRules(String password) =>
    passwordRules.every((r) => r.test(password));

class PasswordRulesList extends StatelessWidget {
  const PasswordRulesList({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: pf.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Semantics(
        label: 'Requisitos de la contraseña',
        child: Column(
          children: [
            for (var i = 0; i < passwordRules.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _RuleRow(
                label: passwordRules[i].label,
                ok: passwordRules[i].test(password),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return Semantics(
      label: '$label, ${ok ? 'cumplido' : 'pendiente'}',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(
            ok ? Icons.check : Icons.circle_outlined,
            size: 18,
            color: ok ? pf.mint : pf.placeholder,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: ok ? pf.text : pf.text2),
            ),
          ),
        ],
      ),
    );
  }
}
