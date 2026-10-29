import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.chat,
    this.size = 48,
    this.showJulia = false,
  });

  final Chat chat;
  final double size;
  final bool showJulia;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final name = chatDisplayName(chat);
    final (bg, fg) = avatarColors(name);
    final url = chat.imageUrl;

    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size >= 48 ? 16 : 15,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );

    final avatar = (url == null || url.isEmpty)
        ? initials
        : ClipOval(
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initials,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : initials,
            ),
          );

    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            if (showJulia)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: pf.mint,
                    shape: BoxShape.circle,
                    border: Border.all(color: pf.surface, width: 2),
                  ),
                  child: Icon(Icons.auto_awesome, size: 11, color: pf.onMint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado de error con "Reintentar" (nunca una pantalla en blanco).
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: pf.text2),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: pf.textMid),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle visual (track + knob) usado en la hoja de filtros y en Julia.
class PfSwitch extends StatelessWidget {
  const PfSwitch({
    super.key,
    required this.value,
    this.width = 52,
    this.height = 32,
    this.knob = 24,
    this.inset = 4,
    this.offColor,
  });

  final bool value;
  final double width;
  final double height;
  final double knob;
  final double inset;
  final Color? offColor;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final on = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: value ? on : (offColor ?? pf.border),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: Container(
            width: knob,
            height: knob,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra superior de una hoja modal (agarre).
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      decoration: BoxDecoration(
        color: PfColors.of(context).border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
