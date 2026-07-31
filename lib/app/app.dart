import 'package:flutter/material.dart';

/// Root application widget.
///
/// Keep this thin: theme, routing, and global providers only.
/// No database or HTTP access from UI layers — see `.ai/standards/`.
class MemosOneApp extends StatelessWidget {
  const MemosOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memos One',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const _BootstrapHome(),
    );
  }
}

class _BootstrapHome extends StatelessWidget {
  const _BootstrapHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memos One')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'One Client. Every Device. Your Memos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Scaffold ready. See .ai/ for architecture & tasks.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
