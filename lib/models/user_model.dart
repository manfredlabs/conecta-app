import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, pastor, supervisor, leader }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? churchId;
  final String? congregationId;
  final String? supervisionId;
  final String? cellId;
  final String? personId;
  final String? gender;
  final DateTime? birthDate;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.churchId,
    this.congregationId,
    this.supervisionId,
    this.cellId,
    this.personId,
    this.gender,
    this.birthDate,
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
      churchId: data['churchId'],
      congregationId: data['congregationId'],
      supervisionId: data['supervisionId'],
      cellId: data['cellId'],
      personId: data['personId'],
      gender: data['gender'],
      birthDate: data['birthDate'] != null
          ? (data['birthDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'churchId': churchId,
      'congregationId': congregationId,
      'supervisionId': supervisionId,
      'cellId': cellId,
      'gender': gender,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
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
