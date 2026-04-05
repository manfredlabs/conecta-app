import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, pastor, supervisor, leader }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? congregationId;
  final String? supervisionId;
  final String? cellId;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.congregationId,
    this.supervisionId,
    this.cellId,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.leader,
      ),
      congregationId: data['congregationId'],
      supervisionId: data['supervisionId'],
      cellId: data['cellId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'congregationId': congregationId,
      'supervisionId': supervisionId,
      'cellId': cellId,
    };
  }

  String get roleDisplayName {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.pastor:
        return 'Pastor de Congregação';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.leader:
        return 'Líder de Célula';
    }
  }
}
