import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/data/app_repository.dart';
import 'core/data/app_scope.dart';
import 'core/firebase/auth_service.dart';
import 'core/firebase/firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screens.dart';
import 'features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional: if initialization fails (no network, missing native
  // config) the app still runs in local demo mode rather than showing a blank
  // screen.
  AuthService? auth;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    auth = AuthService();
  } catch (e) {
    debugPrint('Firebase init failed, running in local mode: $e');
  }

  runApp(WisedonaApp(authService: auth));
}

/// Root widget: owns the repository and routes between auth and the shell.
class WisedonaApp extends StatefulWidget {
  const WisedonaApp({super.key, this.authService});

  /// When null the app runs in local demo mode (used by widget tests).
  final AuthService? authService;

  @override
  State<WisedonaApp> createState() => _WisedonaAppState();
}

class _WisedonaAppState extends State<WisedonaApp> {
  final AppRepository _repo = AppRepository();
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _repo.authService = widget.authService;
    _repo.load();
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: _repo,
      child: MaterialApp(
        title: 'Wisedona',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: AnimatedBuilder(
          animation: _repo,
          builder: (context, _) {
            if (!_splashDone) {
              return SplashScreen(
                onContinue: () => setState(() => _splashDone = true),
              );
            }
            if (!_repo.isSignedIn) {
              return LoginScreen(onSignedIn: () => setState(() {}));
            }
            return const AppShell();
          },
        ),
      ),
    );
  }
}
