import 'package:cloud_firestore/cloud_firestore.dart';

enum ApprovalStatus { pending, approved, rejected }

class ApprovalRequest {
  final String id;
  final String type;
  final String personId;
  final String personName;
  final String cellMemberId;
  final String cellId;
  final String cellName;
  final String? churchId;
  final String requestedBy;
  final String requestedByName;
  final ApprovalStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  ApprovalRequest({
    required this.id,
    required this.type,
    required this.personId,
    required this.personName,
    required this.cellMemberId,
    required this.cellId,
    required this.cellName,
    this.churchId,
    required this.requestedBy,
    required this.requestedByName,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory ApprovalRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ApprovalRequest(
      id: doc.id,
      type: data['type'] ?? '',
      personId: data['personId'] ?? '',
      personName: data['personName'] ?? '',
      cellMemberId: data['cellMemberId'] ?? '',
      cellId: data['cellId'] ?? '',
      cellName: data['cellName'] ?? '',
      churchId: data['churchId'],
      requestedBy: data['requestedBy'] ?? '',
      requestedByName: data['requestedByName'] ?? '',
      status: ApprovalStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ApprovalStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolvedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'personId': personId,
      'personName': personName,
      'cellMemberId': cellMemberId,
      'cellId': cellId,
      'cellName': cellName,
      'churchId': churchId,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
    };
  }
}
