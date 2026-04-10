import 'package:flutter/material.dart';

import 'app/bootstrap/star_kids_bootstrap_app.dart';
import 'app/di/service_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const StarKidsBootstrapApp(
      initialize: ServiceRegistry.bootstrap,
    ),
  );
}
