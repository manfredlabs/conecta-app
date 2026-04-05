import 'package:cloud_firestore/cloud_firestore.dart';

class CellGroup {
  final String id;
  final String name;
  final String supervisionId;
  final String congregationId;
  final String? leaderId;
  final String? leaderName;
  final String? meetingDay;
  final String? address;

  CellGroup({
    required this.id,
    required this.name,
    required this.supervisionId,
    required this.congregationId,
    this.leaderId,
    this.leaderName,
    this.meetingDay,
    this.address,
  });

  factory CellGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CellGroup(
      id: doc.id,
      name: data['name'] ?? '',
      supervisionId: data['supervisionId'] ?? '',
      congregationId: data['congregationId'] ?? '',
      leaderId: data['leaderId'],
      leaderName: data['leaderName'],
      meetingDay: data['meetingDay'],
      address: data['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'supervisionId': supervisionId,
      'congregationId': congregationId,
      'leaderId': leaderId,
      'leaderName': leaderName,
      'meetingDay': meetingDay,
      'address': address,
    };
  }
}
