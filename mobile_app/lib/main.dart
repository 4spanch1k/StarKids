import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di/service_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServiceRegistry.bootstrap();
  runApp(const StarKidsApp());
}
