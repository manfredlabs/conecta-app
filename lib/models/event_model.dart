import 'package:cloud_firestore/cloud_firestore.dart';

class ChurchEvent {
  final String id;
  final String title;
  final DateTime dateTime;
  final String location;
  final String description;
  final String? churchId;
  final String createdBy;
  final DateTime createdAt;

  ChurchEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.description,
    this.churchId,
    required this.createdBy,
    required this.createdAt,
  });

  factory ChurchEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChurchEvent(
      id: doc.id,
      title: data['title'] ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      churchId: data['churchId'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': location,
      'description': description,
      'churchId': churchId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ChurchEvent copyWith({
    String? title,
    DateTime? dateTime,
    String? location,
    String? description,
  }) {
    return ChurchEvent(
      id: id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      description: description ?? this.description,
      churchId: churchId,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
