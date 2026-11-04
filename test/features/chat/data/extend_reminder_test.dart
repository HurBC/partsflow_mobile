import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:partsflow_mobile/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/reminder.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';

class _Remote implements ChatRemoteDataSource {
  Object? createError;
  Object? resolveError;
  final created = <Map<String, Object?>>[];
  final resolved = <String>[];

  @override
  Future<void> createReminder(Map<String, Object?> body) async {
    if (createError != null) throw createError!;
    created.add(body);
  }

  @override
  Future<void> resolveReminder(String id) async {
    resolved.add(id);
    if (resolveError != null) throw resolveError!;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

DioException _net() => DioException(requestOptions: RequestOptions());

Reminder _rem({String chatId = '569@c.us'}) =>
    Reminder(id: '7', chatId: chatId, dueAt: DateTime(2026), comment: 'llamar');

void main() {
  late _Remote remote;
  late ChatRepositoryImpl repo;

  setUp(() {
    remote = _Remote();
    repo = ChatRepositoryImpl(remote);
  });

  test('crea y resuelve: done', () async {
    final r = await repo.extendReminder(
      reminder: _rem(),
      userId: '5',
      minutes: 60,
    );
    expect((r as Ok<ReminderExtendResult>).value, ReminderExtendResult.done);
    expect(remote.created.single['chat_id'], '569@c.us');
    expect(remote.resolved, ['7']);
  });

  test('crea OK y resolver falla: éxito parcial, no fallo plano', () async {
    remote.resolveError = _net();
    final r = await repo.extendReminder(
      reminder: _rem(),
      userId: '5',
      minutes: 60,
    );
    expect(
      (r as Ok<ReminderExtendResult>).value,
      ReminderExtendResult.createdOnly,
    );
    expect(remote.created, hasLength(1));
  });

  test('crear falla: fallo y no se intenta resolver', () async {
    remote.createError = _net();
    final r = await repo.extendReminder(
      reminder: _rem(),
      userId: '5',
      minutes: 60,
    );
    expect(r, isA<Err<ReminderExtendResult>>());
    expect(remote.resolved, isEmpty);
  });

  test('reminder sin chatId usa el id del chat de la hoja', () async {
    await repo.extendReminder(
      reminder: _rem(chatId: ''),
      userId: '5',
      minutes: 60,
      chatId: '569@c.us',
    );
    expect(remote.created.single['chat_id'], '569@c.us');
  });
}
