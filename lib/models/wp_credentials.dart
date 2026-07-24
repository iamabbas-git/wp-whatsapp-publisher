/// Connection details for a single WordPress site, authenticated with an
/// Application Password (Users → Profile → Application Passwords in wp-admin).
class WpCredentials {
  final String siteUrl; // e.g. https://example.com
  final String username;
  final String appPassword;

  const WpCredentials({
    required this.siteUrl,
    required this.username,
    required this.appPassword,
  });

  bool get isComplete =>
      siteUrl.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      appPassword.trim().isNotEmpty;

  /// Site URL without any trailing slashes, ready to append REST paths to.
  String get normalizedSiteUrl =>
      siteUrl.trim().replaceAll(RegExp(r'/+$'), '');

  WpCredentials copyWith({
    String? siteUrl,
    String? username,
    String? appPassword,
  }) {
    return WpCredentials(
      siteUrl: siteUrl ?? this.siteUrl,
      username: username ?? this.username,
      appPassword: appPassword ?? this.appPassword,
    );
  }
}
