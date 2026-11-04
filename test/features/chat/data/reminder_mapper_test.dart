import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/data/mappers/chat_mapper.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/reminder.dart';

void main() {
  test('maps a SAPI reminder row', () {
    final r = reminderFromJson({
      'id': 7,
      'chat_id': '569@c.us',
      'reminder_delta_time': 1760000000000,
      'reminder_type': 'minutes',
      'responsible': '12',
      'comment': ' Llamar ',
      'resolved': false,
      'is_extended': true,
      'is_automatic': false,
    });
    expect(
      r,
      Reminder(
        id: '7',
        chatId: '569@c.us',
        dueAt: DateTime.fromMillisecondsSinceEpoch(1760000000000),
        comment: 'Llamar',
        type: 'minutes',
        responsibleId: '12',
        isExtended: true,
      ),
    );
  });

  test('automatic when no responsible or erp_sync_error; null if invalid', () {
    final base = {
      'id': 1,
      'chat_id': 'c',
      'reminder_delta_time': 1760000000000,
    };
    expect(reminderFromJson({...base, 'responsible': null})!.isAutomatic, true);
    expect(
      reminderFromJson({
        ...base,
        'responsible': '3',
        'reminder_type': 'erp_sync_error',
      })!.isAutomatic,
      true,
    );
    expect(reminderFromJson({...base, 'responsible': '3'})!.isAutomatic, false);
    expect(reminderFromJson({'id': 1}), isNull);
    expect(reminderFromJson({...base, 'resolved': true}), isNull);
    expect(reminderFromJson(null), isNull);
  });
}
