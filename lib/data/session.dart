/// In-memory session store for the currently signed-in user.
///
/// Populated by `LoginView` after `Amplify.Auth.signIn()` succeeds and
/// consumed by [GradeRepository] when sending requests that require an
/// `Authorization: Bearer <token>` header.
class Session {
  static String? userId;   // Cognito 'sub'
  static String? role;     // 'warehouse' | 'customer'
  static String? idToken;  // Raw Cognito ID token (JWT)

  /// True when we have a usable JWT for authenticated API calls.
  static bool get isSignedIn => idToken != null && idToken!.isNotEmpty;

  static void clear() {
    userId = null;
    role = null;
    idToken = null;
  }
}
