import 'package:cloud_firestore/cloud_firestore.dart';

class Supervision {
  final String id;
  final String name;
  final String congregationId;
  final String? supervisorId;
  final String? supervisorName;

  Supervision({
    required this.id,
    required this.name,
    required this.congregationId,
    this.supervisorId,
    this.supervisorName,
  });

  factory Supervision.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Supervision(
      id: doc.id,
      name: data['name'] ?? '',
      congregationId: data['congregationId'] ?? '',
      supervisorId: data['supervisorId'],
      supervisorName: data['supervisorName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'congregationId': congregationId,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
    };
  }
}
