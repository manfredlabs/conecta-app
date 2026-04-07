import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String id;
  final String name;
  final String? phone;
  final String? userId;
  final String cellId;
  final String supervisionId;
  final String congregationId;
  final bool isVisitor;
  final bool isLeader;
  final bool isHelper;
  final String? gender;
  final bool? baptized;
  final DateTime? birthDate;
  final String? email;
  final bool isActive;

  Member({
    required this.id,
    required this.name,
    this.phone,
    this.userId,
    required this.cellId,
    required this.supervisionId,
    required this.congregationId,
    this.isVisitor = false,
    this.isLeader = false,
    this.isHelper = false,
    this.gender,
    this.baptized,
    this.birthDate,
    this.email,
    this.isActive = true,
  });

  factory Member.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Member(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'],
      userId: data['userId'],
      cellId: data['cellId'] ?? '',
      supervisionId: data['supervisionId'] ?? '',
      congregationId: data['congregationId'] ?? '',
      isVisitor: data['isVisitor'] ?? false,
      isLeader: data['isLeader'] ?? false,
      isHelper: data['isHelper'] ?? false,
      gender: data['gender'],
      baptized: data['baptized'],
      birthDate: data['birthDate'] != null
          ? (data['birthDate'] as Timestamp).toDate()
          : null,
      email: data['email'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'userId': userId,
      'cellId': cellId,
      'supervisionId': supervisionId,
      'congregationId': congregationId,
      'isVisitor': isVisitor,
      'isLeader': isLeader,
      'isHelper': isHelper,
      'gender': gender,
      'baptized': baptized,
      'birthDate':
          birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'email': email,
      'isActive': isActive,
    };
  }
}
