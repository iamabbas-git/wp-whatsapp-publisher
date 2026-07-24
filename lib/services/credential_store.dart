import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/wp_credentials.dart';

/// Persists the WordPress connection in the platform keystore/keychain so the
/// application password is never stored in plain text.
class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kSiteUrl = 'wp_site_url';
  static const _kUsername = 'wp_username';
  static const _kAppPassword = 'wp_app_password';

  Future<WpCredentials?> load() async {
    final siteUrl = await _storage.read(key: _kSiteUrl);
    final username = await _storage.read(key: _kUsername);
    final appPassword = await _storage.read(key: _kAppPassword);
    if (siteUrl == null || username == null || appPassword == null) {
      return null;
    }
    return WpCredentials(
      siteUrl: siteUrl,
      username: username,
      appPassword: appPassword,
    );
  }

  Future<void> save(WpCredentials creds) async {
    await _storage.write(key: _kSiteUrl, value: creds.normalizedSiteUrl);
    await _storage.write(key: _kUsername, value: creds.username.trim());
    await _storage.write(key: _kAppPassword, value: creds.appPassword.trim());
  }

  Future<void> clear() async {
    await _storage.delete(key: _kSiteUrl);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kAppPassword);
  }
}
