import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// Converts a Quill document (its Delta JSON operations) into the two output
/// formats the app needs:
///   - HTML for the WordPress post body
///   - WhatsApp-flavoured plain text for the share hand-off
///
/// The same message is authored once and rendered appropriately for each
/// destination. WhatsApp does not understand HTML; it uses its own inline
/// markers: *bold*, _italic_, ~strikethrough~ and ```monospace```.
class MessageConverter {
  /// Full HTML for the WordPress post content. Default (class-based) output is
  /// clean and portable; WordPress renders it fine.
  static String toHtml(List<dynamic> deltaOps) {
    final converter = QuillDeltaToHtmlConverter(
      List<Map<String, dynamic>>.from(deltaOps),
    );
    return converter.convert();
  }

  /// WhatsApp-formatted text. Inline styles become WhatsApp markers; block
  /// structure collapses to newlines (WhatsApp has no headings or lists markup
  /// beyond what we add manually).
  static String toWhatsApp(List<dynamic> deltaOps) {
    final buffer = StringBuffer();

    for (final op in deltaOps) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is! String) {
        // Embeds (e.g. images) can't be inlined into WhatsApp text.
        continue;
      }

      final attrs = (op['attributes'] as Map?) ?? const {};

      // A single op may contain trailing newlines that must stay OUTSIDE the
      // formatting markers, otherwise WhatsApp won't render the style.
      final match = RegExp(r'^(.*?)(\n*)$', dotAll: true).firstMatch(insert)!;
      var core = match.group(1) ?? '';
      final trailingNewlines = match.group(2) ?? '';

      if (core.isNotEmpty) {
        core = _applyMarkers(core, attrs);
      }
      buffer
        ..write(core)
        ..write(trailingNewlines);
    }

    return buffer.toString().trim();
  }

  static String _applyMarkers(String text, Map attrs) {
    // Order matters: innermost first so nested markers wrap correctly.
    var result = text;
    if (attrs['code'] == true) result = '```$result```';
    if (attrs['strike'] == true) result = '~$result~';
    if (attrs['italic'] == true) result = '_${result}_';
    if (attrs['bold'] == true) result = '*$result*';
    return result;
  }
}
