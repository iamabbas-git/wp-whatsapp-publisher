import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';

import '../models/draft.dart';
import '../models/wp_credentials.dart';
import '../services/credential_store.dart';
import '../services/draft_store.dart';
import '../services/message_converter.dart';
import '../services/wordpress_service.dart';
import '../services/whatsapp_share.dart';
import 'drafts_screen.dart';
import 'settings_screen.dart';

/// Main screen: write a message once, publish it to WordPress, then hand it off
/// to WhatsApp groups.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, required this.store});

  final CredentialStore store;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen>
    with WidgetsBindingObserver {
  QuillController _controller = QuillController.basic();
  final TextEditingController _titleCtrl = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  final DraftStore _draftStore = DraftStore();
  final ImagePicker _picker = ImagePicker();

  WpCredentials? _credentials;
  String? _currentDraftId; // set when editing a saved draft
  XFile? _featuredImage; // local featured image, if chosen
  Timer? _autoSaveTimer;
  bool _loadingCreds = true;
  bool _showEmoji = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCredentials();
    // Hide the emoji panel whenever the text keyboard takes focus.
    _editorFocusNode.addListener(() {
      if (_editorFocusNode.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
    // Auto-save as the user types (title + body).
    _titleCtrl.addListener(_scheduleAutoSave);
    _controller.addListener(_scheduleAutoSave);
  }

  /// Debounced auto-save: fires 2s after the last edit so we're not writing on
  /// every keystroke.
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(
      const Duration(seconds: 2),
      () => _saveDraft(showFeedback: false),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save immediately when the app goes to the background, so nothing is lost.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _saveDraft(showFeedback: false);
    }
  }

  Future<void> _loadCredentials() async {
    final creds = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _credentials = creds;
      _loadingCreds = false;
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _titleCtrl.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  bool get _isConnected => _credentials?.isComplete ?? false;

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<WpCredentials>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          store: widget.store,
          initial: _credentials,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _credentials = result);
    }
  }

  bool get _isEmptyComposer =>
      _titleCtrl.text.trim().isEmpty && !_hasContent && _featuredImage == null;

  Future<void> _saveDraft({bool showFeedback = true}) async {
    if (_isEmptyComposer) {
      if (showFeedback) _snack('Nothing to save yet.');
      return;
    }
    final draft = Draft(
      id: _currentDraftId ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      deltaOps: _controller.document.toDelta().toJson(),
      updatedAt: DateTime.now(),
      imagePath: _featuredImage?.path,
    );
    await _draftStore.save(draft);
    _currentDraftId = draft.id;
    if (showFeedback && mounted) _snack('Draft saved');
  }

  Future<void> _openDrafts() async {
    final selected = await Navigator.of(context).push<Draft>(
      MaterialPageRoute(builder: (_) => DraftsScreen(store: _draftStore)),
    );
    if (selected != null && mounted) {
      _loadDraft(selected);
    }
  }

  void _loadDraft(Draft draft) {
    _titleCtrl.text = draft.title;
    final old = _controller;
    setState(() {
      _controller = QuillController(
        document: draft.deltaOps.isEmpty
            ? Document()
            : Document.fromJson(draft.deltaOps),
        selection: const TextSelection.collapsed(offset: 0),
      );
      _controller.addListener(_scheduleAutoSave);
      _currentDraftId = draft.id;
      // Restore the featured image only if the file is still on disk.
      final path = draft.imagePath;
      _featuredImage =
          (path != null && File(path).existsSync()) ? XFile(path) : null;
    });
    old.dispose();
    _snack('Draft loaded');
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _featuredImage = picked);
      _scheduleAutoSave();
    }
  }

  void _removeImage() {
    setState(() => _featuredImage = null);
    _scheduleAutoSave();
  }

  String _mimeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.gif')) return 'image/gif';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _toggleEmoji() {
    if (!_showEmoji) {
      // Drop the text keyboard so the emoji panel has room.
      FocusScope.of(context).unfocus();
    }
    setState(() => _showEmoji = !_showEmoji);
  }

  void _insertEmoji(emoji.Emoji e) {
    final selection = _controller.selection;
    final index =
        selection.baseOffset >= 0 ? selection.baseOffset : _controller.document.length - 1;
    final length =
        selection.isValid && !selection.isCollapsed ? (selection.extentOffset - selection.baseOffset).abs() : 0;
    _controller.replaceText(
      index,
      length,
      e.emoji,
      TextSelection.collapsed(offset: index + e.emoji.length),
    );
  }

  bool get _hasContent =>
      _controller.document.toPlainText().trim().isNotEmpty;

  Future<void> _publish() async {
    if (!_isConnected) {
      _snack('Connect your WordPress site first.');
      _openSettings();
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Add a title for the post.');
      return;
    }
    if (!_hasContent) {
      _snack('Write your message first.');
      return;
    }

    setState(() => _publishing = true);
    final deltaOps = _controller.document.toDelta().toJson();
    final imageForShare = _featuredImage; // capture before reset
    final service = WordPressService(_credentials!);

    try {
      // 1) Upload the featured image first (if any) to get its media id.
      int? featuredMediaId;
      if (_featuredImage != null) {
        final bytes = await _featuredImage!.readAsBytes();
        final media = await service.uploadMedia(
          bytes: bytes,
          filename: _featuredImage!.name,
          mimeType: _mimeFromPath(_featuredImage!.name),
        );
        featuredMediaId = media.id;
      }

      // 2) Create the post, attaching the image as the featured media.
      final html = MessageConverter.toHtml(deltaOps);
      final result = await service.createPost(
        title: _titleCtrl.text.trim(),
        htmlContent: html,
        status: 'publish',
        featuredMediaId: featuredMediaId,
      );

      // The message is now live; remove its saved draft, if any.
      if (_currentDraftId != null) {
        await _draftStore.delete(_currentDraftId!);
        _currentDraftId = null;
      }

      final waText = _buildWhatsAppText(deltaOps, result.link);
      if (!mounted) return;
      setState(() => _publishing = false);
      await _showHandoffSheet(result, waText, imageForShare);
    } on WordPressException catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _snack(e.statusCode == 401
          ? 'WordPress rejected the login. Re-check your connection in settings.'
          : 'Publish failed: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _snack('Could not reach your site. Check your connection and try again.');
    } finally {
      service.close();
    }
  }

  String _buildWhatsAppText(List<dynamic> deltaOps, String postLink) {
    final body = MessageConverter.toWhatsApp(deltaOps);
    final title = _titleCtrl.text.trim();
    final buffer = StringBuffer();
    if (title.isNotEmpty) buffer.writeln('*$title*\n');
    buffer.write(body);
    buffer.write('\n\n$postLink');
    return buffer.toString();
  }

  Future<void> _showHandoffSheet(
    WpPostResult result,
    String waText,
    XFile? image,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Published to WordPress',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result.link,
                  style: const TextStyle(color: Colors.blue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Text(
                  image != null
                      ? 'Now share it to your WhatsApp groups. The share sheet '
                          'opens with your image and caption — pick a group and '
                          'send. Repeat for each group.'
                      : 'Now share it to your WhatsApp groups. WhatsApp opens '
                          'with the message ready — just pick a group and send. '
                          'Repeat for each group.',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    waText,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                  ),
                  onPressed: () async {
                    if (image != null) {
                      await WhatsAppShare.shareImage(image.path, waText);
                    } else {
                      final ok = await WhatsAppShare.openInWhatsApp(waText);
                      if (!ok) {
                        await WhatsAppShare.systemShare(waText);
                      }
                    }
                  },
                  icon: const Icon(Icons.chat),
                  label: Text(
                    image != null ? 'Share to WhatsApp' : 'Open in WhatsApp',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await WhatsAppShare.copyToClipboard(waText);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Copied — paste into any group')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => WhatsAppShare.systemShare(waText),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Share…'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _resetComposer();
                  },
                  child: const Text('Done — start a new message'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetComposer() {
    _titleCtrl.clear();
    _currentDraftId = null;
    // Recreate the controller for a clean document (avoids relying on a
    // document setter, which differs across flutter_quill versions).
    final old = _controller;
    setState(() {
      _controller = QuillController.basic();
      _controller.addListener(_scheduleAutoSave);
      _featuredImage = null;
    });
    old.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New message'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save draft',
            onPressed: () => _saveDraft(),
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Drafts',
            onPressed: _openDrafts,
          ),
          _ConnectionChip(
            connected: _isConnected,
            onTap: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loadingCreds
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_isConnected) _notConnectedBanner(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    controller: _titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Post title',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _featuredImageRow(),
                QuillSimpleToolbar(
                  controller: _controller,
                  config: const QuillSimpleToolbarConfig(
                    showFontFamily: false,
                    showFontSize: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showSearchButton: false,
                    showCodeBlock: false,
                    showDividers: false,
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDADCE0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QuillEditor.basic(
                      controller: _controller,
                      focusNode: _editorFocusNode,
                      scrollController: _editorScrollController,
                      config: const QuillEditorConfig(
                        placeholder: 'Write your message… bold, italics, emojis and more.',
                        padding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                _bottomBar(),
                if (_showEmoji)
                  SizedBox(
                    height: 280,
                    child: emoji.EmojiPicker(
                      onEmojiSelected: (emoji.Category? category, emoji.Emoji e) =>
                          _insertEmoji(e),
                      config: const emoji.Config(),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _notConnectedBanner() {
    return Material(
      color: const Color(0xFFFFF4E5),
      child: InkWell(
        onTap: _openSettings,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF9A6700), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Connect your WordPress site to start publishing.',
                  style: TextStyle(color: Color(0xFF9A6700)),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9A6700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featuredImageRow() {
    if (_featuredImage == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            label: const Text('Add featured image'),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_featuredImage!.path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: const Color(0xFFECECEC),
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Featured image',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: _pickImage,
            child: const Text('Change'),
          ),
          IconButton(
            onPressed: _removeImage,
            icon: const Icon(Icons.close),
            tooltip: 'Remove image',
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: _toggleEmoji,
            icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined),
            tooltip: _showEmoji ? 'Keyboard' : 'Emoji',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              icon: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_publishing ? 'Publishing…' : 'Publish & share'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.connected, required this.onTap});

  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        connected ? Icons.cloud_done : Icons.cloud_off,
        size: 18,
        color: connected ? Colors.green.shade700 : Colors.grey,
      ),
      label: Text(connected ? 'Connected' : 'Connect'),
      onPressed: onTap,
    );
  }
}
