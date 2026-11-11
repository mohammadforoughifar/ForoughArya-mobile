// ============================================================
//  تست پیام‌رسان: نگاشت گفت‌وگو/پیام، برچسب طول ویس و متن خالی
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/messenger/models/chat_models.dart';

void main() {
  test('گفت‌وگو از JSON با کلیدهای camelCase خوانده می‌شود', () {
    final t = ChatThread.fromJson({
      'id': 5,
      'peerUserId': 12,
      'title': 'علی رضایی',
      'lastMessage': 'سلام',
      'unreadCount': 3,
      'isOnline': true,
    });
    expect(t.id, 5);
    expect(t.userId, 12);
    expect(t.title, 'علی رضایی');
    expect(t.unread, 3);
    expect(t.online, true);
    expect(t.initials, 'عر');
  });

  test('گفت‌وگو با کلیدهای PascalCase هم خوانده می‌شود', () {
    final t = ChatThread.fromJson({
      'Id': 7,
      'Title': 'گروه فنی',
      'IsGroup': true,
      'UnreadCount': 1,
    });
    expect(t.id, 7);
    expect(t.isGroup, true);
    expect(t.title, 'گروه فنی');
  });

  test('پیام ویس با مدت و آدرس فایل', () {
    final m = ChatMessage.fromJson({
      'id': 9,
      'type': 'voice',
      'duration': 75,
      'audioUrl': '/media/a.m4a',
      'senderUserId': 3,
    }, myUserId: 3);
    expect(m.kind, ChatKind.voice);
    expect(m.mine, true);
    expect(m.durationLabel, '01:15');
    expect(m.audioUrl, '/media/a.m4a');
  });

  test('پیام متنی دیگران mine نمی‌شود', () {
    final m = ChatMessage.fromJson({
      'id': 10,
      'text': 'سلام',
      'senderUserId': 4,
    }, myUserId: 3);
    expect(m.kind, ChatKind.text);
    expect(m.mine, false);
    expect(m.text, 'سلام');
  });
}
