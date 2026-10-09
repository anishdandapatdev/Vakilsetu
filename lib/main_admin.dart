import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin/admin_preview.dart';
import 'main.dart' show SetupRequiredApp;

void main() {
  const demo = bool.fromEnvironment('DEMO_MODE', defaultValue: !kReleaseMode);
  if (demo) WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(demo ? const AdminPreviewApp() : const SetupRequiredApp());
}
