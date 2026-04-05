import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/congregation_model.dart';
import '../models/supervision_model.dart';
import '../models/cell_model.dart';
import '../models/member_model.dart';
import '../models/meeting_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Congregations ───

  Stream<List<Congregation>> getCongregations() {
    return _db.collection('congregations').snapshots().map(
          (snap) =>
              snap.docs.map((d) => Congregation.fromFirestore(d)).toList(),
        );
  }

  Future<Congregation?> getCongregation(String id) async {
    final doc = await _db.collection('congregations').doc(id).get();
    return doc.exists ? Congregation.fromFirestore(doc) : null;
  }

  Future<void> addCongregation(Congregation congregation) {
    return _db.collection('congregations').add(congregation.toMap());
  }

  // ─── Supervisions ───

  Stream<List<Supervision>> getSupervisions({String? congregationId}) {
    Query<Map<String, dynamic>> query = _db.collection('supervisions');
    if (congregationId != null) {
      query = query.where('congregationId', isEqualTo: congregationId);
    }
    return query.snapshots().map(
          (snap) =>
              snap.docs.map((d) => Supervision.fromFirestore(d)).toList(),
        );
  }

  Future<void> addSupervision(Supervision supervision) {
    return _db.collection('supervisions').add(supervision.toMap());
  }

  // ─── Cells ───

  Stream<List<CellGroup>> getCells({
    String? supervisionId,
    String? congregationId,
    String? leaderId,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('cells');
    if (supervisionId != null) {
      query = query.where('supervisionId', isEqualTo: supervisionId);
    }
    if (congregationId != null) {
      query = query.where('congregationId', isEqualTo: congregationId);
    }
    if (leaderId != null) {
      query = query.where('leaderId', isEqualTo: leaderId);
    }
    return query.snapshots().map(
          (snap) => snap.docs.map((d) => CellGroup.fromFirestore(d)).toList(),
        );
  }

  Future<CellGroup?> getCell(String id) async {
    final doc = await _db.collection('cells').doc(id).get();
    return doc.exists ? CellGroup.fromFirestore(doc) : null;
  }

  Future<void> addCell(CellGroup cell) {
    return _db.collection('cells').add(cell.toMap());
  }

  // ─── Members ───

  Stream<List<Member>> getMembers({required String cellId}) {
    return _db
        .collection('members')
        .where('cellId', isEqualTo: cellId)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => Member.fromFirestore(d)).toList(),
        );
  }

  Future<DocumentReference> addMember(Member member) {
    return _db.collection('members').add(member.toMap());
  }

  Future<void> updateMember(String id, Map<String, dynamic> data) {
    return _db.collection('members').doc(id).update(data);
  }

  Future<void> deleteMember(String id) {
    return _db.collection('members').doc(id).delete();
  }

  // ─── Meetings ───

  Stream<List<Meeting>> getMeetings({
    String? cellId,
    String? supervisionId,
    String? congregationId,
  }) {
    Query<Map<String, dynamic>> query =
        _db.collection('meetings').orderBy('date', descending: true);
    if (cellId != null) {
      query = query.where('cellId', isEqualTo: cellId);
    }
    if (supervisionId != null) {
      query = query.where('supervisionId', isEqualTo: supervisionId);
    }
    if (congregationId != null) {
      query = query.where('congregationId', isEqualTo: congregationId);
    }
    return query.snapshots().map(
          (snap) => snap.docs.map((d) => Meeting.fromFirestore(d)).toList(),
        );
  }

  Future<void> addMeeting(Meeting meeting) {
    return _db.collection('meetings').add(meeting.toMap());
  }

  Future<void> updateMeeting(String id, Map<String, dynamic> data) {
    return _db.collection('meetings').doc(id).update(data);
  }

  Future<void> deleteMeeting(String id) {
    return _db.collection('meetings').doc(id).delete();
  }

  // ─── Users ───

  Stream<List<AppUser>> getUsers() {
    return _db.collection('users').snapshots().map(
          (snap) => snap.docs.map((d) => AppUser.fromFirestore(d)).toList(),
        );
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) {
    return _db.collection('users').doc(id).update(data);
  }
}
