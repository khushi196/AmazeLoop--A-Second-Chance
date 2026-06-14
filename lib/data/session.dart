/// In-memory session store for the currently signed-in user.
///
/// Populated by `LoginView` after `Amplify.Auth.signIn()` succeeds and
/// consumed by [GradeRepository] when sending requests that require an
/// `Authorization: Bearer <token>` header.
library;

import 'package:flutter/foundation.dart';

class Session {
  static String? userId; // Cognito 'sub'
  static String? role; // 'warehouse' | 'customer'
  static String? idToken; // Raw Cognito ID token (JWT)

  /// Bumped whenever auth state changes (login or logout). UI that depends on
  /// [isSignedIn] — e.g. the buyer Purchases/Reserved/Notifications tabs —
  /// listens to this so it rebuilds the moment a user signs in or out, instead
  /// of staying stuck on a stale "please sign in" gate.
  static final ValueNotifier<int> authVersion = ValueNotifier<int>(0);

  /// True when we have a usable JWT for authenticated API calls.
  static bool get isSignedIn => idToken != null && idToken!.isNotEmpty;

  /// Notifies listeners that the session was just populated (post-login).
  /// Call after [userId]/[role]/[idToken] have been set.
  static void notifyChanged() {
    authVersion.value++;
  }

  static void clear() {
    userId = null;
    role = null;
    idToken = null;
    authVersion.value++;
  }
}
