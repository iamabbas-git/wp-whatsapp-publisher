import 'package:flutter/material.dart';

import '../models/draft.dart';
import '../services/draft_store.dart';

/// Shows saved drafts. Tapping one returns it to the compose screen for
/// editing; the trash icon deletes it.
class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key, required this.store});

  final DraftStore store;

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  late Future<List<Draft>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.loadAll();
  }

  void _reload() {
    setState(() => _future = widget.store.loadAll());
  }

  Future<void> _delete(Draft draft) async {
    await widget.store.delete(draft.id);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft deleted')),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drafts')),
      body: FutureBuilder<List<Draft>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final drafts = snapshot.data ?? const [];
          if (drafts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No saved drafts yet.\nWrite a message and tap Save draft.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: drafts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = drafts[i];
              final title = d.title.trim().isEmpty ? 'Untitled' : d.title.trim();
              return ListTile(
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  d.preview.isEmpty ? 'No content' : d.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeAgo(d.updatedAt),
                      style: const TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Delete',
                      onPressed: () => _delete(d),
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).pop(d),
              );
            },
          );
        },
      ),
    );
  }
}
