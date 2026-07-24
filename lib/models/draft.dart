/// A locally-saved message draft. The body is stored as Quill Delta operations
/// (the same JSON the editor produces) so it can be restored exactly.
class Draft {
  final String id;
  final String title;
  final List<dynamic> deltaOps; // Quill Delta ops (list of maps)
  final DateTime updatedAt;
  final String? imagePath; // local path to the featured image, if any

  const Draft({
    required this.id,
    required this.title,
    required this.deltaOps,
    required this.updatedAt,
    this.imagePath,
  });

  /// A short preview of the body text for the drafts list.
  String get preview {
    final buffer = StringBuffer();
    for (final op in deltaOps) {
      if (op is Map && op['insert'] is String) {
        buffer.write(op['insert'] as String);
      }
    }
    return buffer.toString().replaceAll('\n', ' ').trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'delta': deltaOps,
        'updatedAt': updatedAt.toIso8601String(),
        'imagePath': imagePath,
      };

  factory Draft.fromJson(Map<String, dynamic> json) => Draft(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        deltaOps: (json['delta'] as List?) ?? const [],
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        imagePath: json['imagePath'] as String?,
      );
}
