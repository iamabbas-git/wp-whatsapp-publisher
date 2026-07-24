import 'package:flutter_test/flutter_test.dart';
import 'package:wp_wa_publisher/services/message_converter.dart';

// Pure-Dart tests for the message converter. No plugins required, so these run
// reliably in CI with `flutter test`.
void main() {
  group('MessageConverter.toWhatsApp', () {
    test('applies WhatsApp inline markers for bold and italic', () {
      final ops = [
        {'insert': 'Hello '},
        {
          'insert': 'world',
          'attributes': {'bold': true}
        },
        {'insert': ' and '},
        {
          'insert': 'italics',
          'attributes': {'italic': true}
        },
        {'insert': '\n'},
      ];
      expect(
        MessageConverter.toWhatsApp(ops),
        'Hello *world* and _italics_',
      );
    });

    test('keeps trailing newline outside the markers', () {
      final ops = [
        {
          'insert': 'bold',
          'attributes': {'bold': true}
        },
        {'insert': '\n'},
      ];
      expect(MessageConverter.toWhatsApp(ops), '*bold*');
    });

    test('nests bold and italic markers', () {
      final ops = [
        {
          'insert': 'x',
          'attributes': {'bold': true, 'italic': true}
        },
        {'insert': '\n'},
      ];
      expect(MessageConverter.toWhatsApp(ops), '*_x_*');
    });

    test('wraps strikethrough and inline code', () {
      final strike = [
        {
          'insert': 'gone',
          'attributes': {'strike': true}
        },
        {'insert': '\n'},
      ];
      final code = [
        {
          'insert': 'run()',
          'attributes': {'code': true}
        },
        {'insert': '\n'},
      ];
      expect(MessageConverter.toWhatsApp(strike), '~gone~');
      expect(MessageConverter.toWhatsApp(code), '```run()```');
    });
  });

  group('MessageConverter.toHtml', () {
    test('produces HTML containing the plain text', () {
      final ops = [
        {'insert': 'Hello world\n'},
      ];
      expect(MessageConverter.toHtml(ops), contains('Hello world'));
    });

    test('emits bold markup for bold runs', () {
      final ops = [
        {
          'insert': 'hi',
          'attributes': {'bold': true}
        },
        {'insert': '\n'},
      ];
      final html = MessageConverter.toHtml(ops).toLowerCase();
      expect(html.contains('<strong>') || html.contains('<b>'), isTrue);
    });
  });
}
