import 'package:cloud_firestore/cloud_firestore.dart';

class Congregation {
  final String id;
  final String name;
  final String? pastorId;
  final String? pastorName;

  Congregation({
    required this.id,
    required this.name,
    this.pastorId,
    this.pastorName,
  });

  factory Congregation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Congregation(
      id: doc.id,
      name: data['name'] ?? '',
      pastorId: data['pastorId'],
      pastorName: data['pastorName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'pastorId': pastorId,
      'pastorName': pastorName,
    };
  }
}
