import 'package:cloud_firestore/cloud_firestore.dart';

class Church {
  final String id;
  final String name;
  final String code; // código único pra seleção (ex: "maranata-sp")
  final DateTime createdAt;

  Church({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
  });

  factory Church.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Church(
      id: doc.id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
