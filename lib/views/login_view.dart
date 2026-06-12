import 'package:flutter/material.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  String _selectedRole = 'warehouse'; // Default role selection

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header Section ---
                    const Text(
                      'AmazeLoop',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF232F3E), // Amazon Squid Ink
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A Second Chance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),

                    // --- Form Section ---
                    // Email Input
                    Text(
                      'EMAIL ADDRESS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.mail_outline, color: Colors.grey),
                        hintText: 'name@company.com',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Password Input
                    Text(
                      'PASSWORD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                        hintText: '••••••••',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Role Selection
                    Text(
                      'I AM A:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildRoleCard('Warehouse / Seller', 'warehouse')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildRoleCard('Customer', 'customer')),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 32),

                    // --- Action Buttons ---
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: const Color(0xFF232F3E),
                            ),
                            child: const Text(
                              'SIGN UP',
                              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            // THE CRITICAL ROUTING HOOK
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/dashboard');
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              elevation: 0,
                            ),
                            child: const Text(
                              'LOG IN',
                              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Footer
                    Center(
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF232F3E)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Forgot password?'),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to keep the Role Selection code clean
  Widget _buildRoleCard(String title, String value) {
    final isSelected = _selectedRole == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF9900).withOpacity(0.05) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? const Color(0xFFFF9900) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFF9900) : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF111111),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}