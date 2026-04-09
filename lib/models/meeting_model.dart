import 'package:cloud_firestore/cloud_firestore.dart';

class Visitor {
  final String name;
  final String gender;
  final bool baptized;
  final DateTime? birthDate;
  final String? phone;

  Visitor({
    required this.name,
    required this.gender,
    required this.baptized,
    this.birthDate,
    this.phone,
  });

  factory Visitor.fromMap(Map<String, dynamic> map) {
    return Visitor(
      name: map['name'] ?? '',
      gender: map['gender'] ?? 'M',
      baptized: map['baptized'] ?? false,
      birthDate: map['birthDate'] != null
          ? (map['birthDate'] as Timestamp).toDate()
          : null,
      phone: map['phone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gender': gender,
      'baptized': baptized,
      'birthDate':
          birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'phone': phone,
    };
  }
}

class Meeting {
  final String id;
  final String cellId;
  final String supervisionId;
  final String congregationId;
  final String? churchId;
  final DateTime date;
  final List<String> presentMemberIds;
  final Map<String, String> memberRoles;
  final List<Visitor> visitors;
  final String? observations;
  final String createdBy;

  Meeting({
    required this.id,
    required this.cellId,
    required this.supervisionId,
    required this.congregationId,
    this.churchId,
    required this.date,
    required this.presentMemberIds,
    this.memberRoles = const {},
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
      churchId: data['churchId'],
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      presentMemberIds: List<String>.from(data['presentMemberIds'] ?? []),
      memberRoles: Map<String, String>.from(data['memberRoles'] ?? {}),
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
      'churchId': churchId,
      'date': Timestamp.fromDate(date),
      'presentMemberIds': presentMemberIds,
      'memberRoles': memberRoles,
      'visitors': visitors.map((v) => v.toMap()).toList(),
      'observations': observations,
      'createdBy': createdBy,
    };
  }

  int get totalPresent => presentMemberIds.length + visitors.length;
}
