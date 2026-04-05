import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String id;
  final String name;
  final String? phone;
  final String cellId;
  final String supervisionId;
  final String congregationId;

  Member({
    required this.id,
    required this.name,
    this.phone,
    required this.cellId,
    required this.supervisionId,
    required this.congregationId,
  });

  factory Member.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Member(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'],
      cellId: data['cellId'] ?? '',
      supervisionId: data['supervisionId'] ?? '',
      congregationId: data['congregationId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'cellId': cellId,
      'supervisionId': supervisionId,
      'congregationId': congregationId,
    };
  }
}
