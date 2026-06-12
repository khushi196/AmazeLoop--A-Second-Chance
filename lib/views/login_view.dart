import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../data/session.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  String _selectedRole = 'warehouse'; // Default role selection
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _message;
  bool _isError = false;
  bool _isLoginLoading = false;
  bool _isSignUpLoading = false;
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final role = _selectedRole;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Please enter both email and password.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isSignUpLoading = true;
      _isLoginLoading = false;
      _message = null;
    });

    try {
      await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.email: email,
            const CognitoUserAttributeKey.custom('role'): role,
          },
        ),
      );
      setState(() {
        _message = 'Account created. Please log in.';
        _isError = false;
      });
    } on AuthException catch (e) {
      setState(() {
        _message = e.message;
        _isError = true;
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
        _isError = true;
      });
    } finally {
      setState(() {
        _isSignUpLoading = false;
      });
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Please enter both email and password.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoginLoading = true;
      _isSignUpLoading = false;
      _message = null;
    });

    try {
      // Ensure no stale session from a previous confirmSignUp flow
      try {
        await Amplify.Auth.signOut();
      } catch (_) {}

      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        // Fetch user attributes
        final attributes = await Amplify.Auth.fetchUserAttributes();

        for (final attr in attributes) {
          if (attr.userAttributeKey.key == 'sub') {
            Session.userId = attr.value;
          }
          if (attr.userAttributeKey.key == 'custom:role') {
            Session.role = attr.value;
          }
        }

        // Load grading history for this user
        await _loadHistory(Session.userId!);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else if (result.nextStep.signInStep == AuthSignInStep.confirmSignUp) {
        // User exists but hasn't confirmed their email yet — trigger verification flow
        await Amplify.Auth.resendSignUpCode(username: email);
        setState(() {
          _isLoginLoading = false;
        });
        if (mounted) {
          _showVerificationDialog(email);
        }
        return;
      } else {
        setState(() {
          _message = 'Sign-in not complete. Step required: ${result.nextStep.signInStep}';
          _isError = true;
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _message = e.message;
        _isError = true;
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
        _isError = true;
      });
    } finally {
      setState(() {
        _isLoginLoading = false;
      });
    }
  }

  /// Loads grading history for the logged-in user.
  /// Body will be implemented when the history backend is ready.
  Future<void> _loadHistory(String userId) async {
    // TODO: Fetch grading history from backend for this userId
  }

  /// Shows a dialog prompting the user for their email verification code.
  void _showVerificationDialog(String email) {
    final password = _passwordController.text.trim();
    _codeController.clear();
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Verify Your Email', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A verification code has been sent to:',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter verification code',
                      prefixIcon: Icon(Icons.lock_clock_outlined, color: Colors.grey),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        dialogError!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final code = _codeController.text.trim();
                    if (code.isEmpty) {
                      setDialogState(() {
                        dialogError = 'Please enter the code.';
                      });
                      return;
                    }
                    try {
                      final confirmResult = await Amplify.Auth.confirmSignUp(
                        username: email,
                        confirmationCode: code,
                      );
                      if (confirmResult.isSignUpComplete) {
                        // Auto-login after successful verification
                        try {
                          await Amplify.Auth.signOut();
                          final signInResult = await Amplify.Auth.signIn(
                            username: email,
                            password: password,
                          );
                          if (signInResult.isSignedIn) {
                            // Fetch user attributes
                            final attributes = await Amplify.Auth.fetchUserAttributes();
                            for (final attr in attributes) {
                              if (attr.userAttributeKey.key == 'sub') {
                                Session.userId = attr.value;
                              }
                              if (attr.userAttributeKey.key == 'custom:role') {
                                Session.role = attr.value;
                              }
                            }
                            await _loadHistory(Session.userId!);

                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            if (mounted) {
                              Navigator.pushReplacementNamed(this.context, '/dashboard');
                            }
                            return;
                          } else {
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            setState(() {
                              _message = 'Verification successful but auto-login failed. Please log in again.';
                              _isError = true;
                            });
                          }
                        } on AuthException catch (e) {
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          setState(() {
                            _message = 'Verification successful but login failed: ${e.message}';
                            _isError = true;
                          });
                        }
                      } else {
                        setDialogState(() {
                          dialogError = 'Verification not complete. Try again.';
                        });
                      }
                    } on AuthException catch (e) {
                      setDialogState(() {
                        dialogError = e.message;
                      });
                    } catch (e) {
                      setDialogState(() {
                        dialogError = e.toString();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9900),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Code'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows the initial forgot-password dialog asking for email.
  void _showForgotPasswordDialog() {
    final emailForReset = TextEditingController(text: _emailController.text.trim());
    String? dialogError;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the email address associated with your account.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailForReset,
                    enabled: !isDialogLoading,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline, color: Colors.grey),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        dialogError!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading ? null : () async {
                    final email = emailForReset.text.trim();
                    if (email.isEmpty) {
                      setDialogState(() {
                        dialogError = 'Please enter your email.';
                      });
                      return;
                    }
                    setDialogState(() {
                      isDialogLoading = true;
                      dialogError = null;
                    });
                    try {
                      final result = await Amplify.Auth.resetPassword(username: email);
                      if (result.nextStep.updateStep == AuthResetPasswordStep.confirmResetPasswordWithCode) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _showConfirmResetDialog(email);
                      } else {
                        setDialogState(() {
                          isDialogLoading = false;
                          dialogError = 'Unexpected step: ${result.nextStep.updateStep}';
                        });
                      }
                    } on AuthException catch (e) {
                      setDialogState(() {
                        isDialogLoading = false;
                        dialogError = e.message;
                      });
                    } catch (e) {
                      setDialogState(() {
                        isDialogLoading = false;
                        dialogError = e.toString();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9900),
                    foregroundColor: Colors.white,
                  ),
                  child: isDialogLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Code'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows the second dialog to enter the code and new password.
  void _showConfirmResetDialog(String email) {
    final resetCodeController = TextEditingController();
    final newPasswordController = TextEditingController();
    String? dialogError;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Enter New Password', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "We've sent a code to $email",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetCodeController,
                    enabled: !isDialogLoading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                      prefixIcon: Icon(Icons.lock_clock_outlined, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    enabled: !isDialogLoading,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        dialogError!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading ? null : () async {
                    final code = resetCodeController.text.trim();
                    final newPassword = newPasswordController.text.trim();
                    if (code.isEmpty || newPassword.isEmpty) {
                      setDialogState(() {
                        dialogError = 'Please fill in both fields.';
                      });
                      return;
                    }
                    setDialogState(() {
                      isDialogLoading = true;
                      dialogError = null;
                    });
                    try {
                      await Amplify.Auth.confirmResetPassword(
                        username: email,
                        newPassword: newPassword,
                        confirmationCode: code,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      setState(() {
                        _message = 'Password reset successful. Please log in with your new password.';
                        _isError = false;
                      });
                    } on AuthException catch (e) {
                      setDialogState(() {
                        isDialogLoading = false;
                        dialogError = e.message;
                      });
                    } catch (e) {
                      setDialogState(() {
                        isDialogLoading = false;
                        dialogError = e.toString();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9900),
                    foregroundColor: Colors.white,
                  ),
                  child: isDialogLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Reset Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
                      controller: _emailController,
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
                      controller: _passwordController,
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
                    if (_message != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isError ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _isError ? Colors.red.shade200 : Colors.green.shade200),
                        ),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _isError ? Colors.red.shade700 : Colors.green.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (_isSignUpLoading || _isLoginLoading) ? null : _signUp,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: const Color(0xFF232F3E),
                            ),
                            child: _isSignUpLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text(
                                    'SIGN UP',
                                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_isSignUpLoading || _isLoginLoading) ? null : _login,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              elevation: 0,
                            ),
                            child: _isLoginLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text(
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
                        onPressed: _showForgotPasswordDialog,
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