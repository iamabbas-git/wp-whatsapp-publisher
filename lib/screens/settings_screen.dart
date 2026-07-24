import 'package:flutter/material.dart';

import '../models/wp_credentials.dart';
import '../services/credential_store.dart';
import '../services/wordpress_service.dart';

/// Lets the user connect their WordPress site using an Application Password.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.initial,
  });

  final CredentialStore store;
  final WpCredentials? initial;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _siteCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;

  bool _obscure = true;
  bool _busy = false;
  String? _statusMessage;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    _siteCtrl = TextEditingController(text: widget.initial?.siteUrl ?? 'https://');
    _userCtrl = TextEditingController(text: widget.initial?.username ?? '');
    _passCtrl = TextEditingController(text: widget.initial?.appPassword ?? '');
  }

  @override
  void dispose() {
    _siteCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  WpCredentials get _current => WpCredentials(
        siteUrl: _siteCtrl.text,
        username: _userCtrl.text,
        appPassword: _passCtrl.text,
      );

  Future<void> _testAndSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    final service = WordPressService(_current);
    try {
      final name = await service.testConnection();
      await widget.store.save(_current);
      if (!mounted) return;
      setState(() {
        _statusOk = true;
        _statusMessage = 'Connected as $name. Saved.';
      });
      // Give the user a beat to read the success message, then return the creds.
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context).pop(_current.copyWith(
        siteUrl: _current.normalizedSiteUrl,
      ));
    } on WordPressException catch (e) {
      setState(() {
        _statusOk = false;
        _statusMessage = e.statusCode == 401
            ? 'Login failed. Check the username and application password.'
            : e.message;
      });
    } catch (e) {
      setState(() {
        _statusOk = false;
        _statusMessage = 'Could not reach the site. Check the URL and your connection.';
      });
    } finally {
      service.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect WordPress')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Enter your site and an Application Password.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'In wp-admin, go to Users → Profile → Application Passwords, create '
              'one named "Publisher App", and paste it below. This is safer than '
              'your login password and can be revoked any time.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _siteCtrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Site URL',
                hintText: 'https://yourblog.com',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Enter your site URL';
                final uri = Uri.tryParse(t);
                if (uri == null || !uri.isAbsolute || !uri.scheme.startsWith('http')) {
                  return 'Enter a full URL including https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _userCtrl,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'WordPress username',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter your username' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Application password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Paste the application password' : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _testAndSave,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(_busy ? 'Testing…' : 'Test & save connection'),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusOk ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
