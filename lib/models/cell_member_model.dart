import 'package:cloud_firestore/cloud_firestore.dart';
import 'person_model.dart';

class CellMember {
  final String id;
  final String personId;
  final String personName; // denormalizado pra performance
  final String cellId;
  final String supervisionId;
  final String congregationId;
  final bool isLeader;
  final bool isHelper;
  final bool isVisitor;
  final bool isActive;

  // Populated after join with people collection
  Person? person;

  CellMember({
    required this.id,
    required this.personId,
    required this.personName,
    required this.cellId,
    required this.supervisionId,
    required this.congregationId,
    this.isLeader = false,
    this.isHelper = false,
    this.isVisitor = false,
    this.isActive = true,
    this.person,
  });

  factory CellMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CellMember(
      id: doc.id,
      personId: data['personId'] ?? '',
      personName: data['personName'] ?? '',
      cellId: data['cellId'] ?? '',
      supervisionId: data['supervisionId'] ?? '',
      congregationId: data['congregationId'] ?? '',
      isLeader: data['isLeader'] ?? false,
      isHelper: data['isHelper'] ?? false,
      isVisitor: data['isVisitor'] ?? false,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'personId': personId,
      'personName': personName,
      'cellId': cellId,
      'supervisionId': supervisionId,
      'congregationId': congregationId,
      'isLeader': isLeader,
      'isHelper': isHelper,
      'isVisitor': isVisitor,
      'isActive': isActive,
    };
  }

  // Getters — usam person quando disponível, fallback pra denormalized
  String get name => person?.name ?? personName;
  String? get phone => person?.phone;
  String? get gender => person?.gender;
  bool? get baptized => person?.baptized;
  DateTime? get birthDate => person?.birthDate;
  String? get email => person?.email;
  String? get userId => person?.userId;
}
