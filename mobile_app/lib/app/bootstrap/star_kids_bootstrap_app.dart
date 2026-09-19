import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';

class StarKidsBootstrapApp extends StatefulWidget {
  const StarKidsBootstrapApp({
    super.key,
    required this.initialize,
  });

  final Future<void> Function() initialize;

  @override
  State<StarKidsBootstrapApp> createState() => _StarKidsBootstrapAppState();
}

class _StarKidsBootstrapAppState extends State<StarKidsBootstrapApp> {
  @override
  void initState() {
    super.initState();
    debugPrint('[BOOT] Bootstrap app init started');
    unawaited(_initializeInBackground());
  }

  Future<void> _initializeInBackground() async {
    try {
      await widget.initialize();
      debugPrint('[BOOT] Bootstrap app init completed');
    } catch (error) {
      // StarKidsApp owns the auth/settings state and can render a usable
      // unauthenticated/offline shell even if a non-critical startup step
      // fails. Never hold the first frame behind this future.
      debugPrint('[BOOT] Bootstrap app init failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const StarKidsApp();
  }
}
