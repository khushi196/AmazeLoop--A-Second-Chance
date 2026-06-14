import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../BuyerDashboard.dart';
import '../SellIntroScreen.dart';
import '../data/repositories/grade_repository.dart';
import '../data/session.dart';

/// Where the user came from. Used to decide what role to assign on signup
/// (so they don't have to pick) and where to send them after a successful
/// login.
enum LoginEntry {
  /// Reached from a buy/reserve gate or the marketplace navbar; default role
  /// is `customer` and post-login lands at the buyer dashboard.
  buyer,

  /// Reached from `Sell / Trade-in → Individual seller`; role is locked to
  /// `customer` and post-login lands at the customer Sell Intro screen.
  customerSell,

  /// Reached from `Sell / Trade-in → Warehouse`; role is locked to
  /// `warehouse` and post-login lands at the warehouse dashboard.
  warehouseSell,
}

class LoginView extends StatefulWidget {
  final LoginEntry entry;
  const LoginView({super.key, this.entry = LoginEntry.buyer});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final String _selectedRole = _initialRole();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _message;
  bool _isError = false;
  bool _isLoginLoading = false;
  bool _isSignUpLoading = false;
  bool _showPassword = false;
  final TextEditingController _codeController = TextEditingController();

  String _initialRole() {
    switch (widget.entry) {
      case LoginEntry.warehouseSell:
        return 'warehouse';
      case LoginEntry.customerSell:
      case LoginEntry.buyer:
        return 'customer';
    }
  }

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
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.email: email,
            const CognitoUserAttributeKey.custom('role'): role,
          },
        ),
      );

      if (!result.isSignUpComplete &&
          result.nextStep.signUpStep == AuthSignUpStep.confirmSignUp) {
        // Cognito already sent a verification code as part of signUp.
        // Show the dialog immediately and reuse THAT code — do not trigger
        // another send (that was the cause of two codes arriving).
        setState(() {
          _isSignUpLoading = false;
          _message = null;
        });
        if (mounted) _showVerificationDialog(email);
        return;
      }

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
        await _populateSession();

        // Load grading history for this user
        await _loadHistory(Session.userId!);

        if (mounted) {
          _routeByRole();
        }
      } else if (result.nextStep.signInStep == AuthSignInStep.confirmSignUp) {
        // User exists but hasn't confirmed their email yet. Open the
        // verification dialog WITHOUT auto-resending — a code was already
        // sent at sign-up. The dialog has a "Resend code" button for when
        // the original has expired, so we don't waste a second email.
        setState(() {
          _isLoginLoading = false;
        });
        if (mounted) {
          _showVerificationDialog(email);
        }
        return;
      } else {
        setState(() {
          _message =
              'Sign-in not complete. Step required: ${result.nextStep.signInStep}';
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

  /// Preloads grading history after login so the History tab renders instantly.
  Future<void> _loadHistory(String userId) async {
    // Fire-and-forget — the HistoryView already fetches on mount,
    // this is just a best-effort cache warm-up that doesn't block login.
    try {
      await GradeRepository().listEvaluations(userId: userId, limit: 20);
    } catch (_) {
      // Non-fatal — History tab will fetch on open.
    }
  }

  /// Reads user attributes (sub, custom:role) and the Cognito ID token from
  /// the current Amplify session, and stores them on [Session].
  Future<void> _populateSession() async {
    // 1. User attributes give us sub + custom:role.
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      for (final attr in attributes) {
        if (attr.userAttributeKey.key == 'sub') {
          Session.userId = attr.value;
        }
        if (attr.userAttributeKey.key == 'custom:role') {
          Session.role = attr.value;
        }
      }
    } catch (e) {
      debugPrint('fetchUserAttributes failed: $e');
    }
    // Default to 'customer' so the role is never null downstream.
    Session.role ??= 'customer';

    // 2. Auth session gives us the raw JWT for API authorization.
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        final tokens = session.userPoolTokensResult.value;
        Session.idToken = tokens.idToken.raw;
      }
    } catch (e) {
      // Token capture is best-effort; unauthenticated endpoints still work.
      debugPrint('fetchAuthSession failed: $e');
    }
  }

  /// After a successful login, sends the user to the screen appropriate
  /// for their entry path and role, and clears the navigation stack so
  /// back-button can't drop them back into the login form.
  void _routeByRole() {
    Widget destination;
    switch (widget.entry) {
      case LoginEntry.warehouseSell:
        // Warehouse path: always end at the seller dashboard.
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
        return;
      case LoginEntry.customerSell:
        // Customer "I want to sell" path: end at the Sell Intro.
        destination = const SellIntroScreen();
        break;
      case LoginEntry.buyer:
        // Marketplace gate / general buyer path: route by stored role.
        if (Session.role == 'warehouse') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (route) => false,
          );
          return;
        }
        destination = const BuyerDashboard();
        break;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Verify Your Email',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A verification code has been sent to:',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter verification code',
                      prefixIcon: Icon(
                        Icons.lock_clock_outlined,
                        color: Colors.grey,
                      ),
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
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      await Amplify.Auth.resendSignUpCode(username: email);
                      setDialogState(() {
                        dialogError = null;
                      });
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('A new code has been sent.')),
                        );
                      }
                    } on AuthException catch (e) {
                      setDialogState(() {
                        dialogError = e.message;
                      });
                    }
                  },
                  child: const Text('Resend code'),
                ),
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
                            await _populateSession();
                            await _loadHistory(Session.userId!);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              _routeByRole();
                            }
                            return;
                          } else {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            setState(() {
                              _message =
                                  'Verification successful but auto-login failed. Please log in again.';
                              _isError = true;
                            });
                          }
                        } on AuthException catch (e) {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          setState(() {
                            _message =
                                'Verification successful but login failed: ${e.message}';
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
    final emailForReset = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? dialogError;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Reset Password',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading
                      ? null
                      : () async {
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
                            final result = await Amplify.Auth.resetPassword(
                              username: email,
                            );
                            if (result.nextStep.updateStep ==
                                AuthResetPasswordStep
                                    .confirmResetPasswordWithCode) {
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              _showConfirmResetDialog(email);
                            } else {
                              setDialogState(() {
                                isDialogLoading = false;
                                dialogError =
                                    'Unexpected step: ${result.nextStep.updateStep}';
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
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Enter New Password',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                      prefixIcon: Icon(
                        Icons.lock_clock_outlined,
                        color: Colors.grey,
                      ),
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
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading
                      ? null
                      : () async {
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
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            setState(() {
                              _message =
                                  'Password reset successful. Please log in with your new password.';
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
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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
      backgroundColor: const Color(0xFFEEF0F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ─── Mascot illustration ───
                    _buildMascot(),
                    const SizedBox(height: 24),

                    // ─── Logo text ───
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(text: 'Amaze', style: TextStyle(color: Color(0xFF232F3E))),
                          TextSpan(text: 'Loop', style: TextStyle(color: Color(0xFFFF9900))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A Second Chance for Great Tech',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF232F3E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Orange underline ───
                    Container(
                      width: 50,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9900),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Welcome text ───
                    const Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Log in to continue to your account',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Email field ───
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Email address',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline, color: Colors.grey.shade500, size: 20),
                        hintText: 'Enter your email',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFFF9900), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Password field ───
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                        hintText: 'Enter your password',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFFF9900), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Error/Success message ───
                    if (_message != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isError ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isError ? Colors.red.shade200 : Colors.green.shade200,
                          ),
                        ),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _isError ? Colors.red.shade700 : Colors.green.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Log In button (primary) ───
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isSignUpLoading || _isLoginLoading) ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9900),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoginLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'LOG IN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Sign Up button (secondary) ───
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: (_isSignUpLoading || _isLoginLoading) ? null : _signUp,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111111),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSignUpLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'SIGN UP',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Forgot password ───
                    TextButton(
                      onPressed: _showForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(fontSize: 13),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Mascot — cardboard box with recycle arrows, sparkles, and leaves
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMascot() {
    return SizedBox(
      height: 100,
      width: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sparkles
          Positioned(
            top: 0,
            left: 20,
            child: Icon(Icons.auto_awesome, size: 14, color: const Color(0xFFFF9900).withValues(alpha: 0.7)),
          ),
          Positioned(
            top: 8,
            right: 15,
            child: Icon(Icons.auto_awesome, size: 10, color: const Color(0xFFFF9900).withValues(alpha: 0.5)),
          ),
          // Recycle arrows
          const Positioned(
            top: 5,
            child: Icon(Icons.sync, size: 28, color: Color(0xFF232F3E)),
          ),
          // Box
          Positioned(
            bottom: 0,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFE8C99B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD4A76A), width: 2),
              ),
              child: Stack(
                children: [
                  // Tape strip
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4A6572),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                  ),
                  // Eyes
                  Positioned(
                    top: 28,
                    left: 18,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF333333), shape: BoxShape.circle),
                    ),
                  ),
                  Positioned(
                    top: 28,
                    right: 18,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF333333), shape: BoxShape.circle),
                    ),
                  ),
                  // Smile
                  Positioned(
                    bottom: 16,
                    left: 22,
                    right: 22,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: const Color(0xFF333333), width: 2),
                          left: BorderSide(color: const Color(0xFF333333), width: 2),
                          right: BorderSide(color: const Color(0xFF333333), width: 2),
                        ),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Leaf
          Positioned(
            bottom: 20,
            right: 0,
            child: Icon(Icons.eco, size: 24, color: Colors.green.shade400),
          ),
        ],
      ),
    );
  }
}
