import 'package:cloud_firestore/cloud_firestore.dart';

class Person {
  final String id;
  final String name;
  final String? phone;
  final String? gender;
  final bool? baptized;
  final DateTime? birthDate;
  final String? email;
  final String congregationId;
  final String? churchId;
  final String? userId;

  Person({
    required this.id,
    required this.name,
    this.phone,
    this.gender,
    this.baptized,
    this.birthDate,
    this.email,
    required this.congregationId,
    this.churchId,
    this.userId,
  });

  factory Person.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Person(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'],
      gender: data['gender'],
      baptized: data['baptized'],
      birthDate: data['birthDate'] != null
          ? (data['birthDate'] as Timestamp).toDate()
          : null,
      email: data['email'],
      congregationId: data['congregationId'] ?? '',
      churchId: data['churchId'],
      userId: data['userId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'gender': gender,
      'baptized': baptized,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'email': email,
      'congregationId': congregationId,
      'churchId': churchId,
      'userId': userId,
    };
  }
}
