import 'package:flutter/material.dart';
import 'views/login_view.dart';
import 'views/dashboard_layout.dart';

void main() {
  runApp(const AmazonLoopApp());
}

class AmazonLoopApp extends StatelessWidget {
  const AmazonLoopApp({super.key});

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
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginView(),
        '/dashboard': (context) => const DashboardLayout(),
      },
    );
  }
}