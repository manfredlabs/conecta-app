import 'package:cloud_firestore/cloud_firestore.dart';

class Supervision {
  final String id;
  final String name;
  final String congregationId;
  final String? churchId;
  final String? supervisorId;
  final String? supervisorName;

  Supervision({
    required this.id,
    required this.name,
    required this.congregationId,
    this.churchId,
    this.supervisorId,
    this.supervisorName,
  });

  factory Supervision.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Supervision(
      id: doc.id,
      name: data['name'] ?? '',
      congregationId: data['congregationId'] ?? '',
      churchId: data['churchId'],
      supervisorId: data['supervisorId'],
      supervisorName: data['supervisorName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'congregationId': congregationId,
      'churchId': churchId,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
    };
  }
}
