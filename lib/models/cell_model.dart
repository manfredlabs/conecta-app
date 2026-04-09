import 'package:cloud_firestore/cloud_firestore.dart';

class CellGroup {
  final String id;
  final String name;
  final String supervisionId;
  final String congregationId;
  final String? churchId;
  final String? leaderId;
  final String? leaderName;
  final String? meetingDay;
  final String? meetingTime;
  final String? address;

  CellGroup({
    required this.id,
    required this.name,
    required this.supervisionId,
    required this.congregationId,
    this.churchId,
    this.leaderId,
    this.leaderName,
    this.meetingDay,
    this.meetingTime,
    this.address,
  });

  factory CellGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CellGroup(
      id: doc.id,
      name: data['name'] ?? '',
      supervisionId: data['supervisionId'] ?? '',
      congregationId: data['congregationId'] ?? '',
      churchId: data['churchId'],
      leaderId: data['leaderId'],
      leaderName: data['leaderName'],
      meetingDay: data['meetingDay'],
      meetingTime: data['meetingTime'],
      address: data['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'supervisionId': supervisionId,
      'congregationId': congregationId,
      'churchId': churchId,
      'leaderId': leaderId,
      'leaderName': leaderName,
      'meetingDay': meetingDay,
      'meetingTime': meetingTime,
      'address': address,
    };
  }

  CellGroup copyWith({
    String? name,
    String? supervisionId,
    String? congregationId,
    String? churchId,
    String? leaderId,
    String? leaderName,
    String? meetingDay,
    String? meetingTime,
    String? address,
  }) {
    return CellGroup(
      id: id,
      name: name ?? this.name,
      supervisionId: supervisionId ?? this.supervisionId,
      congregationId: congregationId ?? this.congregationId,
      churchId: churchId ?? this.churchId,
      leaderId: leaderId ?? this.leaderId,
      leaderName: leaderName ?? this.leaderName,
      meetingDay: meetingDay ?? this.meetingDay,
      meetingTime: meetingTime ?? this.meetingTime,
      address: address ?? this.address,
    );
  }
}
