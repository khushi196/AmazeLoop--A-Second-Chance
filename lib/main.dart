import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'amplifyconfiguration.dart';
import 'views/login_view.dart';
import 'views/dashboard_layout.dart';

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amazon Loop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEAEDED), // Amazon Gray
        primaryColor: const Color(0xFFFF9900), // Amazon Orange
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFFFF9900),
          secondary: const Color(0xFF232F3E), // Amazon Squid Ink
          surface: Colors.white,
        ),
        fontFamily: 'Inter',
        
        // Global Input Field Styling
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
      ),
      home: _amplifyConfigured
          ? const LoginView()
          : const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9900)),
              ),
            ),
      routes: {
        '/login': (context) => const LoginView(),
        '/dashboard': (context) => const DashboardLayout(),
      },
    );
  }
}