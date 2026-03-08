import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

/// Converts raw exceptions into user-friendly messages.
/// Never exposes internal/technical details to the end user.
String friendlyErrorMessage(dynamic error) {
  // ── Firebase Auth ──
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

  // ── Socket / IO errors ──
  if (error is SocketException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('refused')) return 'Connection refused. Make sure the device is on and reachable.';
    if (msg.contains('timed out') || msg.contains('timeout')) return 'Connection timed out. Check the IP address and try again.';
    if (msg.contains('no route') || msg.contains('unreachable')) return 'Device not reachable. Check your network connection.';
    return 'Could not connect. Check the address and try again.';
  }

  // ── File system errors ──
  if (error is FileSystemException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('permission') || msg.contains('denied')) return 'Permission denied. Check app storage permissions.';
    if (msg.contains('no such file') || msg.contains('not found')) return 'File not found. It may have been moved or deleted.';
    if (msg.contains('no space')) return 'Not enough storage space on your device.';
    return 'Could not access the file. Please try again.';
  }

  final msg = error.toString().toLowerCase();

  // ── Bluetooth / printer errors ──
  if (msg.contains('bluetooth')) {
    if (msg.contains('turned off') || msg.contains('disabled')) return 'Bluetooth is turned off. Please enable it in your device settings.';
    if (msg.contains('not found') || msg.contains('no device')) return 'Printer not found. Make sure it is paired and turned on.';
    if (msg.contains('closed') || msg.contains('timeout') || msg.contains('timed out')) return 'Lost connection to the printer. Try reconnecting.';
    return 'Could not connect to printer. Make sure it is on and paired.';
  }

  if (msg.contains('printer') || msg.contains('print')) {
    if (msg.contains('not connected')) return 'Printer is not connected. Connect it first in Settings.';
    if (msg.contains('paper') || msg.contains('jam')) return 'Printer error — check for paper jams or empty paper roll.';
    return 'Printing failed. Check the printer and try again.';
  }

  // ── Network / connectivity ──
  if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
    if (msg.contains('refused')) return 'Connection refused. Make sure the device is on and reachable.';
    if (msg.contains('timeout') || msg.contains('timed out')) return 'Connection timed out. Please try again.';
    return 'Connection error. Check your internet and try again.';
  }
  if (msg.contains('timeout') || msg.contains('timed out')) {
    return 'Request timed out. Please try again.';
  }

  // ── Permission ──
  if (msg.contains('permission') || msg.contains('denied')) {
    return 'You don\'t have permission to perform this action.';
  }

  // ── Email / SMTP ──
  if (msg.contains('smtp') || msg.contains('mail')) {
    return 'Could not send the email. Please try again later.';
  }

  return 'Something went wrong. Please try again.';
}
