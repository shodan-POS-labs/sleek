import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, cashier }

class AppUser {
  final String uid;
  final String shopId;
  final String name;
  final String pinHash;
  final UserRole role;
  final String? email; // Admin only for cloud backup
  final bool biometricEnabled;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.shopId,
    required this.name,
    required this.pinHash,
    required this.role,
    this.email,
    this.biometricEnabled = false,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    return AppUser(
      uid: documentId,
      shopId: data['shopId'] ?? '',
      name: data['name'] ?? '',
      pinHash: data['pinHash'] ?? '',
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.cashier,
      email: data['email'],
      biometricEnabled: data['biometricEnabled'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'pinHash': pinHash,
      'role': role.name,
      'email': email,
      'biometricEnabled': biometricEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
