import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  const requestedDemoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );
  if (requestedDemoMode) {
    // Keep accessible labels available throughout the preview's lifetime.
    WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  }
  runApp(
    requestedDemoMode
        ? const DemoPreview(showBanner: true)
        : const VakilSetuApp(),
  );
}

class DemoPreview extends StatelessWidget {
  final bool showBanner;
  const DemoPreview({super.key, this.showBanner = true});
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: showBanner
        ? const Banner(
            message: 'DEMO',
            location: BannerLocation.topEnd,
            child: VakilSetuApp(),
          )
        : const VakilSetuApp(),
  );
}

class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Setup required. Configure API_ENABLED and API_BASE_URL for a connected build, or DEMO_MODE for a labeled preview.',
          ),
        ),
      ),
    ),
  );
}
