import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/messenger/data/chat_endpoints.dart';

void main() {
  test('سرور پیام‌رسان به‌صورت پیش‌فرض hard-code شده است', () {
    expect(ChatEndpoints.defaultServer, 'https://94.183.59.57:4457');
    expect(ChatEndpoints.defaultChatPath, '/chat');
  });

  test('آدرس نهایی چت از سرور پیام‌رسان ساخته می‌شود', () {
    final url = ChatEndpoints.fullUrl(
      ChatEndpoints.defaultServer,
      ChatEndpoints.defaultChatPath,
    );
    expect(url, 'https://94.183.59.57:4457/chat');
  });

  test('آدرس کامل دست‌نخورده می‌ماند', () {
    expect(
      ChatEndpoints.fullUrl(
        ChatEndpoints.defaultServer,
        'https://94.183.59.57:4457/chat',
      ),
      'https://94.183.59.57:4457/chat',
    );
  });
}
