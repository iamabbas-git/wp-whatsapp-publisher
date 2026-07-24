import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'screens/compose_screen.dart';
import 'services/credential_store.dart';

void main() {
  runApp(const PublisherApp());
}

class PublisherApp extends StatelessWidget {
  const PublisherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CredentialStore();
    return MaterialApp(
      title: 'WP + WhatsApp Publisher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF128C7E), // WhatsApp teal
        useMaterial3: true,
      ),
      // flutter_quill requires its localization delegates to be registered.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ComposeScreen(store: store),
    );
  }
}
