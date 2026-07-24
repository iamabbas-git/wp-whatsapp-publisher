import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/wp_credentials.dart';

/// Result of a successful post creation.
class WpPostResult {
  final int id;
  final String link; // public URL of the new post
  final String status;

  const WpPostResult({
    required this.id,
    required this.link,
    required this.status,
  });
}

/// Result of a successful media (image) upload.
class WpMedia {
  final int id;
  final String sourceUrl; // public URL of the uploaded file

  const WpMedia({required this.id, required this.sourceUrl});
}

/// Raised when the WordPress REST API returns an error.
class WordPressException implements Exception {
  final int statusCode;
  final String message;

  WordPressException(this.statusCode, this.message);

  @override
  String toString() => 'WordPress error ($statusCode): $message';
}

/// Thin client over the WordPress REST API (wp/v2), authenticated with an
/// Application Password using HTTP Basic auth over HTTPS.
class WordPressService {
  WordPressService(this.credentials, {http.Client? client})
      : _client = client ?? http.Client();

  final WpCredentials credentials;
  final http.Client _client;

  Uri _endpoint(String path) =>
      Uri.parse('${credentials.normalizedSiteUrl}/wp-json/wp/v2/$path');

  String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('${credentials.username.trim()}:${credentials.appPassword.trim()}'))}';

  Map<String, String> get _headers => {
        'Authorization': _authHeader,
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };

  /// Verifies the credentials by fetching the authenticated user.
  /// Returns the display name on success.
  Future<String> testConnection() async {
    final res = await _client
        .get(_endpoint('users/me'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['name'] as String?) ?? credentials.username;
    }
    throw WordPressException(res.statusCode, _extractMessage(res.body));
  }

  /// Creates a post. [status] is typically 'publish' or 'draft'.
  /// Pass [featuredMediaId] to set the post's featured image.
  Future<WpPostResult> createPost({
    required String title,
    required String htmlContent,
    String status = 'publish',
    int? featuredMediaId,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'content': htmlContent,
      'status': status,
    };
    if (featuredMediaId != null) {
      payload['featured_media'] = featuredMediaId;
    }

    final res = await _client
        .post(
          _endpoint('posts'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return WpPostResult(
        id: body['id'] as int,
        link: (body['link'] as String?) ?? credentials.normalizedSiteUrl,
        status: (body['status'] as String?) ?? status,
      );
    }
    throw WordPressException(res.statusCode, _extractMessage(res.body));
  }

  /// Uploads an image to the media library. Returns its id and public URL.
  /// Send the raw bytes with a Content-Disposition filename, as the REST API
  /// expects for binary media uploads.
  Future<WpMedia> uploadMedia({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final res = await _client
        .post(
          _endpoint('media'),
          headers: {
            'Authorization': _authHeader,
            'Content-Type': mimeType,
            'Content-Disposition': 'attachment; filename="$filename"',
            'Accept': 'application/json',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return WpMedia(
        id: body['id'] as int,
        sourceUrl: (body['source_url'] as String?) ?? '',
      );
    }
    throw WordPressException(res.statusCode, _extractMessage(res.body));
  }

  /// WordPress returns errors as {"code": ..., "message": "..."}.
  String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // fall through
    }
    return body.isEmpty ? 'Unknown error' : body;
  }

  void close() => _client.close();
}
