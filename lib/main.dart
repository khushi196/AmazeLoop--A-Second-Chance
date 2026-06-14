import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'amplifyconfiguration.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AmazonLoopApp());
}

class AmazonLoopApp extends StatefulWidget {
  const AmazonLoopApp({super.key});

  @override
  State<AmazonLoopApp> createState() => _AmazonLoopAppState();
}

class _AmazonLoopAppState extends State<AmazonLoopApp> {
  bool _amplifyConfigured = false;
  String? _amplifyError;

  @override
  void initState() {
    super.initState();
    _configureAmplify();
  }

  Future<void> _configureAmplify() async {
    try {
      final authPlugin = AmplifyAuthCognito();
      await Amplify.addPlugins([authPlugin]);
      await Amplify.configure(amplifyconfig);
      setState(() {
        _amplifyConfigured = true;
      });
    } on AmplifyAlreadyConfiguredException {
      setState(() {
        _amplifyConfigured = true;
      });
    } catch (e) {
      debugPrint('Error configuring Amplify: $e');
      setState(() {
        _amplifyError = 'Failed to initialise. Please restart the app.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      scaffoldBackgroundColor: const Color(0xFFEAEDED),
      primaryColor: const Color(0xFFFF9900),
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: const Color(0xFFFF9900),
        secondary: const Color(0xFF232F3E),
        surface: Colors.white,
      ),
      fontFamily: 'Inter',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFD5D9D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFFF9900), width: 2),
        ),
      ),
    );

    // While Amplify is configuring (or if it failed), show a plain app shell.
    if (_amplifyError != null) {
      return MaterialApp(
        title: 'AmazeLoop',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_amplifyError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _configureAmplify, child: const Text('Retry')),
            ]),
          ),
        ),
      );
    }
    if (!_amplifyConfigured) {
      return MaterialApp(
        title: 'AmazeLoop',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Color(0xFFFF9900))),
        ),
      );
    }

    // Configured → URL-based router so the browser arrows work everywhere.
    return MaterialApp.router(
      title: 'AmazeLoop',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: appRouter,
    );
  }
}
