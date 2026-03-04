import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../models/app_user.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  // Hashes the 6-digit PIN before saving/comparing
  String _hashPin(String pin) {
    if (pin.isEmpty) return '';
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // Admin registers the Shop and themselves
  Future<AppUser> registerShopAndAdmin({
    required String shopName,
    required String adminName,
    required String email,
    required String password,
    String businessType = 'retail',
  }) async {
    // 1. Create User in Firebase Auth
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = userCredential.user!.uid;

    // 2. Create Shop Document
    final shopRef = await _firestore.collection('shops').add({
      'name': shopName,
      'businessType': businessType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Create AppUser Document in Firestore
    final appUser = AppUser(
      uid: uid,
      shopId: shopRef.id,
      name: adminName,
      pinHash: '', // Set later
      role: UserRole.admin,
      email: email.trim(),
      createdAt: DateTime.now(),
      biometricEnabled: false,
    );

    await _firestore.collection('users').doc(uid).set(appUser.toMap());
    
    // Auto-login and update session
    await _updateEmailLoginSession(uid);
    _currentUser = appUser;
    
    return appUser;
  }

  // Admin sets their PIN after shop registration
  Future<void> setupAdminPIN(String pin) async {
    if (_currentUser == null) throw Exception("No user logged in to set PIN.");
    
    final hashedPin = _hashPin(pin);
    await _firestore.collection('users').doc(_currentUser!.uid).update({
      'pinHash': hashedPin,
    });
    
    _currentUser = AppUser(
      uid: _currentUser!.uid,
      shopId: _currentUser!.shopId,
      name: _currentUser!.name,
      pinHash: hashedPin,
      role: _currentUser!.role,
      email: _currentUser!.email,
      createdAt: _currentUser!.createdAt,
      biometricEnabled: _currentUser!.biometricEnabled,
    );
  }

  // Add Cashier using secondary Firebase App to prevent signing out Admin
  Future<void> addCashier({
    required String name,
    required String email,
    required String password,
    required String pin,
  }) async {
    if (_currentUser == null) throw Exception("Must be logged in to add cashiers.");

    // Create a secondary Firebase App
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );

    try {
      final authSecondary = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCredential = await authSecondary.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      final uid = userCredential.user!.uid;
      final hashedPin = _hashPin(pin);

      // Create cashier profile in Firestore
      final appUser = AppUser(
        uid: uid,
        shopId: _currentUser!.shopId,
        name: name,
        pinHash: hashedPin,
        role: UserRole.cashier,
        email: email.trim(),
        createdAt: DateTime.now(),
        biometricEnabled: false,
      );

      await _firestore.collection('users').doc(uid).set(appUser.toMap());
    } finally {
      // Delete the secondary app instance to clean up
      await secondaryApp.delete();
    }
  }

  // Login with Email and Password
  Future<AppUser> loginWithEmail({required String email, required String password}) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    
    final uid = userCredential.user!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    
    if (!doc.exists) throw Exception("User profile not found in database.");

    final user = AppUser.fromMap(doc.data()!, doc.id);
    
    await _updateEmailLoginSession(uid);
    _currentUser = user;
    return user;
  }

  // Update session time after successful email/password login
  Future<void> _updateEmailLoginSession(String uid) async {
    await _storage.write(key: 'session_uid', value: uid);
    await _storage.write(key: 'last_uid', value: uid); 
    await _storage.write(
      key: '${uid}_last_email_login', 
      value: DateTime.now().toIso8601String()
    );
  }

  // Login using 6-digit PIN
  Future<AppUser?> loginWithPIN(String pin) async {
    final hashedPin = _hashPin(pin);
    
    try {
      // Find the user with this PIN hash
      final snapshot = await _firestore
          .collection('users')
          .where('pinHash', isEqualTo: hashedPin)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final user = AppUser.fromMap(doc.data(), doc.id);
        
        // Check 30-day session expiry
        await _validate30DaySession(user.uid);

        await _storage.write(key: 'session_uid', value: user.uid);
        _currentUser = user;
        return user;
      }
    } catch (e) {
      if (e is StateError) {
        rethrow; // Propagate session expired error
      }
      print("Error logging in with PIN: $e");
    }
    return null;
  }

  // Validate if the user has logged in with Email/Password within the last 30 days
  Future<void> _validate30DaySession(String uid) async {
    final lastLoginStr = await _storage.read(key: '${uid}_last_email_login');
    if (lastLoginStr == null) {
      throw StateError('Session expired. Please log in with your email and password.');
    }

    final lastLogin = DateTime.parse(lastLoginStr);
    final daysPassed = DateTime.now().difference(lastLogin).inDays;

    if (daysPassed > 30) {
      throw StateError('30-day session expired. Please log in with your email and password.');
    }
  }

  // Try to check if last email login allows automatic background user loading for Biometrics
  Future<bool> hasValidSessionForBiometrics() async {
    final savedUid = await _storage.read(key: 'last_uid');
    if (savedUid == null) return false;
    
    try {
      await _validate30DaySession(savedUid);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Attempt login using Biometrics
  Future<AppUser?> loginWithBiometrics() async {
    final savedUid = await _storage.read(key: 'last_uid');
    if (savedUid == null) return null;

    try {
      // Check 30-day expiry before even prompting fingerprint
      await _validate30DaySession(savedUid);

      final doc = await _firestore.collection('users').doc(savedUid).get();
      if (!doc.exists) return null;

      final user = AppUser.fromMap(doc.data()!, doc.id);
      if (!user.biometricEnabled) return null;

      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return null;

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Sleek (${user.name})',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (authenticated) {
        await _storage.write(key: 'session_uid', value: user.uid);
        _currentUser = user;
        return user;
      }
    } catch (e) {
      if (e is StateError) {
        rethrow; // Propagate session expired error to UI
      }
      print("Error with biometrics: $e");
    }
    return null;
  }

  // Toggle biometrics for the currently logged in user
  Future<bool> toggleBiometrics(bool enable) async {
    if (_currentUser == null) return false;

    if (enable) {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        throw Exception('Biometric hardware is not available on this device.');
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        throw Exception('No biometrics enrolled. Please register a fingerprint or face ID in your device settings.');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric login for Sleek',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (!authenticated) return false;
    }

    await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'biometricEnabled': enable});

    _currentUser = AppUser(
      uid: _currentUser!.uid,
      shopId: _currentUser!.shopId,
      name: _currentUser!.name,
      pinHash: _currentUser!.pinHash,
      role: _currentUser!.role,
      email: _currentUser!.email,
      createdAt: _currentUser!.createdAt,
      biometricEnabled: enable,
    );

    return true;
  }

  // Verify the current user's PIN
  bool verifyPin(String pin) {
    if (_currentUser == null) return false;
    return _currentUser!.pinHash == _hashPin(pin);
  }

  // Update user profile (Name and/or PIN)
  Future<void> updateUserProfile({required String name, String? pin}) async {
    if (_currentUser == null) throw Exception("No user logged in to update.");

    final Map<String, dynamic> updates = {'name': name};
    String currentPinHash = _currentUser!.pinHash;

    if (pin != null && pin.isNotEmpty && pin.length == 6) {
      currentPinHash = _hashPin(pin);
      updates['pinHash'] = currentPinHash;
    }

    await _firestore.collection('users').doc(_currentUser!.uid).update(updates);

    // Refresh singleton
    _currentUser = AppUser(
      uid: _currentUser!.uid,
      shopId: _currentUser!.shopId,
      name: name,
      pinHash: currentPinHash,
      role: _currentUser!.role,
      email: _currentUser!.email,
      createdAt: _currentUser!.createdAt,
      biometricEnabled: _currentUser!.biometricEnabled,
    );
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _storage.delete(key: 'session_uid');
    // We intentionally keep 'last_uid' and '${uid}_last_email_login' so they can use PIN later if session is active
    _currentUser = null;
  }

  // ── Password / PIN Reset ──────────────────────────────────────────────────

  /// Send Firebase Auth password reset email (admin self-service)
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  /// Admin resets a cashier's PIN directly (no old PIN needed)
  Future<void> adminResetCashierPin({
    required String cashierUid,
    required String newPin,
  }) async {
    if (_currentUser == null || _currentUser!.role != UserRole.admin) {
      throw Exception('Only admins can reset cashier PINs.');
    }
    final hashed = _hashPin(newPin);
    await _firestore.collection('users').doc(cashierUid).update({
      'pinHash': hashed,
    });
  }

  /// Get all users (cashiers + admins) for the current shop
  Future<List<AppUser>> getShopUsers() async {
    if (_currentUser == null) return [];
    final snapshot = await _firestore
        .collection('users')
        .where('shopId', isEqualTo: _currentUser!.shopId)
        .get();
    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Find the admin user for a given shop (for cashier reset-request notifications)
  Future<AppUser?> getShopAdmin(String shopId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('shopId', isEqualTo: shopId)
        .where('role', isEqualTo: 'admin')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return AppUser.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
  }
}
