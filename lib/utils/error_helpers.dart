import 'package:firebase_auth/firebase_auth.dart';

/// Converts raw exceptions into user-friendly messages.
/// Never exposes internal/technical details to the end user.
String friendlyErrorMessage(dynamic error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  final msg = error.toString().toLowerCase();

  if (msg.contains('network') || msg.contains('socket') || msg.contains('connection') || msg.contains('stream')) {
    return 'Connection error. Check your internet and try again.';
  }
  if (msg.contains('timeout')) {
    return 'Request timed out. Please try again.';
  }
  if (msg.contains('permission')) {
    return 'You don\'t have permission to perform this action.';
  }

  return 'Something went wrong. Please try again.';
}
