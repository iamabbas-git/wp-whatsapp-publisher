import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles the compliant WhatsApp hand-off. We never send messages on the
/// user's behalf; we simply open WhatsApp (or the system share sheet) with the
/// message pre-filled so the user picks the group(s) and taps send.
class WhatsAppShare {
  /// Opens WhatsApp directly on its chat picker with [text] pre-filled.
  /// Returns false if WhatsApp could not be opened (e.g. not installed).
  static Future<bool> openInWhatsApp(String text) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Opens the Android system share sheet (WhatsApp will appear as a target,
  /// alongside other apps). Good fallback if the direct link fails.
  static Future<void> systemShare(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  /// Shares an image with a caption via the system share sheet. WhatsApp's
  /// direct text link can't carry an image, so we use the share sheet here —
  /// the user picks the group and sends the image + caption together.
  static Future<void> shareImage(String imagePath, String caption) async {
    await Share.shareXFiles([XFile(imagePath)], text: caption);
  }

  /// Copies the WhatsApp-formatted text to the clipboard so the user can paste
  /// it into several groups quickly.
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
