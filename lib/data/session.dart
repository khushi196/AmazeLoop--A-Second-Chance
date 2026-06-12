/// In-memory session store for the currently logged-in user.
class Session {
  static String? userId; // Cognito 'sub'
  static String? role;   // 'warehouse' or 'customer'

  static void clear() {
    userId = null;
    role = null;
  }
}
