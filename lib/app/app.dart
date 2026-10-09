import 'package:flutter/material.dart';

import '../design_system/ui.dart';
import '../core/config/api_config.dart';
import 'app_shell.dart';
import 'demo_store.dart';
import '../features/authentication/data/api_auth_repository.dart';
import '../features/authentication/presentation/login_page.dart';

class VakilSetuApp extends StatelessWidget {
  const VakilSetuApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VakilSetu · Advocate network',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: ApiConfig.enabled ? const _AuthenticationGate() : const LoginPage(),
  );
}

class _AuthenticationGate extends StatefulWidget {
  const _AuthenticationGate();

  @override
  State<_AuthenticationGate> createState() => _AuthenticationGateState();
}

class _AuthenticationGateState extends State<_AuthenticationGate> {
  final repository = ApiAuthRepository();
  late final session = repository.restoreSession();

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasData) {
        return AppShell(store: DemoStore(), authRepository: repository);
      }
      return LoginPage(authRepository: repository);
    },
  );
}
