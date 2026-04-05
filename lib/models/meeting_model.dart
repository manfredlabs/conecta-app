import 'package:cloud_firestore/cloud_firestore.dart';

class Visitor {
  final String name;
  final String? phone;

  Visitor({required this.name, this.phone});

  factory Visitor.fromMap(Map<String, dynamic> map) {
    return Visitor(
      name: map['name'] ?? '',
      phone: map['phone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
    };
  }
}

class Meeting {
  final String id;
  final String cellId;
  final String supervisionId;
  final String congregationId;
  final DateTime date;
  final List<String> presentMemberIds;
  final List<Visitor> visitors;
  final String? observations;
  final String createdBy;

  Meeting({
    required this.id,
    required this.cellId,
    required this.supervisionId,
    required this.congregationId,
    required this.date,
    required this.presentMemberIds,
    this.visitors = const [],
    this.observations,
    required this.createdBy,
  });

  factory Meeting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meeting(
      id: doc.id,
      cellId: data['cellId'] ?? '',
      supervisionId: data['supervisionId'] ?? '',
      congregationId: data['congregationId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      presentMemberIds: List<String>.from(data['presentMemberIds'] ?? []),
      visitors: (data['visitors'] as List<dynamic>?)
              ?.map((v) => Visitor.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      observations: data['observations'],
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'supervisionId': supervisionId,
      'congregationId': congregationId,
      'date': Timestamp.fromDate(date),
      'presentMemberIds': presentMemberIds,
      'visitors': visitors.map((v) => v.toMap()).toList(),
      'observations': observations,
      'createdBy': createdBy,
    };
  }

  int get totalPresent => presentMemberIds.length + visitors.length;
}
