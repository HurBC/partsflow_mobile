import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';

const _dias = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _two(int n) => n.toString().padLeft(2, '0');

String hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysBetween(DateTime a, DateTime b) => _day(a).difference(_day(b)).inDays;

/// Hora en la lista: hoy HH:mm, ayer "Ayer", esta semana día corto, si no dd/MM/yy.
String listTime(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final n = now ?? DateTime.now();
  final diff = _daysBetween(n, d);
  if (diff <= 0) return hm(d);
  if (diff == 1) return 'Ayer';
  if (diff < 7) return _diasCortos[d.weekday - 1];
  return '${_two(d.day)}/${_two(d.month)}/${_two(d.year % 100)}';
}

/// Separador de día: Hoy, Ayer, día de la semana (menos de 7 días) o «12 de marzo de 2026».
String dayLabel(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = _daysBetween(n, d);
  if (diff <= 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  if (diff < 7) return _dias[d.weekday - 1];
  final year = d.year == n.year ? '' : ' de ${d.year}';
  return '${d.day} de ${_meses[d.month - 1]}$year';
}

bool sameDay(DateTime a, DateTime b) => _day(a) == _day(b);

String relativeShort(DateTime d, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return '1 min';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  return '${diff.inDays} d';
}

/// «+56 9 1234 5678» para móviles chilenos; «+dígitos» en otro caso.
String formatPhone(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('56')) {
    return '+56 ${d[2]} ${d.substring(3, 7)} ${d.substring(7)}';
  }
  return d.isEmpty ? '' : '+$d';
}

/// "+56 9 •••• 4821".
String maskPhone(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('56')) {
    return '+56 ${d[2]} •••• ${d.substring(7)}';
  }
  if (d.length >= 7) {
    return '+${d.substring(0, math.min(2, d.length - 6))} •••• ${d.substring(d.length - 4)}';
  }
  return d.isEmpty ? '' : '+$d';
}

String chatDisplayName(Chat c) {
  final a = c.client?.name?.trim();
  if (a != null && a.isNotEmpty) return a;
  final b = c.name?.trim();
  if (b != null && b.isNotEmpty) return b;
  final d = c.contactName?.trim();
  if (d != null && d.isNotEmpty) return d;
  final p = formatPhone(c.phone);
  return p.isEmpty ? 'Sin nombre' : p;
}

String initialsOf(String name) {
  final words = name
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

/// Pares (fondo, texto) del avatar según el nombre; todos con contraste AA.
const _avatarPairs = [
  (Color(0xFFE4E6F7), Color(0xFF181D84)),
  (Color(0xFFDCF7EE), Color(0xFF0B5A4F)),
  (Color(0xFFE0ECFF), Color(0xFF1E40AF)),
  (Color(0xFFFDE7F3), Color(0xFF9D174D)),
  (Color(0xFFFFF1DB), Color(0xFF7A4B00)),
];

(Color, Color) avatarColors(String seed) {
  var h = 0;
  for (final u in seed.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  final p = _avatarPairs[h % _avatarPairs.length];
  return p;
}

String previewFor(ChatLastMessage? m) {
  if (m == null) return '';
  final body = m.body?.trim();
  if (body != null && body.isNotEmpty) return body;
  return switch (m.type) {
    'image' => 'Foto',
    'audio' || 'ptt' || 'voice' => 'Audio',
    'video' => 'Video',
    'document' => 'Documento',
    'sticker' => 'Sticker',
    'location' => 'Ubicación',
    'contacts' => 'Contacto',
    _ => '',
  };
}

IconData iconForType(String? type) => switch (type) {
  'image' => Icons.photo_outlined,
  'audio' || 'ptt' || 'voice' => Icons.mic_none,
  'video' => Icons.videocam_outlined,
  'document' => Icons.insert_drive_file_outlined,
  'sticker' => Icons.emoji_emotions_outlined,
  'location' => Icons.place_outlined,
  'contacts' => Icons.person_outline,
  _ => Icons.chat_bubble_outline,
};

String labelForType(String type) => switch (type) {
  'image' => 'Foto',
  'audio' || 'ptt' || 'voice' => 'Audio',
  'video' => 'Video',
  'document' => 'Documento',
  'sticker' => 'Sticker',
  'location' => 'Ubicación',
  'contacts' => 'Contacto',
  'text' => 'Mensaje',
  _ => 'Mensaje no compatible',
};
