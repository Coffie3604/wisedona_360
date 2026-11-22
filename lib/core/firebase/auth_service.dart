import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper over [FirebaseAuth] that turns Firebase's exception soup into
/// short, user-facing messages.
///
/// Kept separate from [AppRepository] so the repository stays testable without
/// a live Firebase project.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in with email + password.
  ///
  /// Returns `null` on success, or a human-readable error message.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _messageFor(e);
    } catch (e) {
      debugPrint('AuthService.signIn failed: $e');
      return 'Something went wrong. Please try again.';
    }
  }

  /// Creates an account and sets the display name.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final trimmed = name.trim();
      if (trimmed.isNotEmpty) {
        await cred.user?.updateDisplayName(trimmed);
        await cred.user?.reload();
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _messageFor(e);
    } catch (e) {
      debugPrint('AuthService.register failed: $e');
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _messageFor(e);
    } catch (e) {
      debugPrint('AuthService.sendPasswordReset failed: $e');
      return 'Could not send the reset email.';
    }
  }

  Future<void> signOut() => _auth.signOut();

  static String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled for this project.';
      case 'invalid-api-key':
      case 'app-not-authorized':
        return 'This build is not registered with Firebase. '
            'Add the Android/iOS app in the Firebase console.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
