import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/api_config.dart';

void main() {
  // A release must explicitly select the connected API or a labeled demo.
  // Server-readable messaging is supported; E2EE is not claimed here.
  const requestedDemoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: !kReleaseMode,
  );
  const demoMode = requestedDemoMode && !ApiConfig.enabled;
  if (demoMode) {
    // Keep accessible labels available throughout the preview's lifetime.
    WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  }
  runApp(
    demoMode || ApiConfig.enabled
        ? DemoPreview(showBanner: demoMode)
        : const SetupRequiredApp(),
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
