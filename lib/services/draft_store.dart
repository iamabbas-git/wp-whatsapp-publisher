import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/draft.dart';

/// Stores message drafts locally on the device using shared_preferences.
/// Drafts are kept as a single JSON array under one key.
class DraftStore {
  static const _key = 'saved_drafts_v1';

  Future<List<Draft>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final drafts = list
          .map((e) => Draft.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      // Most recently edited first.
      drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return drafts;
    } catch (_) {
      return [];
    }
  }

  /// Inserts a new draft or updates the existing one with the same id.
  Future<void> save(Draft draft) async {
    final drafts = await loadAll();
    final idx = drafts.indexWhere((d) => d.id == draft.id);
    if (idx >= 0) {
      drafts[idx] = draft;
    } else {
      drafts.add(draft);
    }
    await _persist(drafts);
  }

  Future<void> delete(String id) async {
    final drafts = await loadAll();
    drafts.removeWhere((d) => d.id == id);
    await _persist(drafts);
  }

  Future<void> _persist(List<Draft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
