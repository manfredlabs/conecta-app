import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/congregation_model.dart';
import '../models/supervision_model.dart';
import '../models/cell_model.dart';
import '../models/member_model.dart';
import '../models/person_model.dart';
import '../models/cell_member_model.dart';
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

  Future<void> updateCongregation(String id, Map<String, dynamic> data) {
    return _db.collection('congregations').doc(id).update(data);
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

  Future<void> updateSupervision(String id, Map<String, dynamic> data) {
    return _db.collection('supervisions').doc(id).update(data);
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

  Future<void> updateCell(String id, Map<String, dynamic> data) {
    return _db.collection('cells').doc(id).update(data);
  }

  Future<Map<String, String>> getCellNames(Set<String> cellIds) async {
    final map = <String, String>{};
    for (final id in cellIds) {
      if (id.isEmpty) continue;
      try {
        final doc = await _db.collection('cells').doc(id).get();
        if (doc.exists) {
          map[id] = (doc.data()?['name'] as String?) ?? '';
        }
      } catch (_) {}
    }
    return map;
  }

  /// Returns a map of userId → role name for members that have a linked user
  Future<Map<String, String>> getUserRoles(Set<String> userIds) async {
    final map = <String, String>{};
    for (final uid in userIds) {
      if (uid.isEmpty) continue;
      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (doc.exists) {
          map[uid] = (doc.data()?['role'] as String?) ?? 'leader';
        }
      } catch (_) {}
    }
    return map;
  }

  /// Returns a map of member name (lowercase) → user role for all users
  Future<Map<String, String>> getUserRolesByName() async {
    final snap = await _db.collection('users').get();
    final map = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['name'] as String?)?.toLowerCase() ?? '';
      final role = (data['role'] as String?) ?? 'leader';
      if (name.isNotEmpty) map[name] = role;
    }
    return map;
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

  Future<List<Member>> getMembersByCell(String cellId) async {
    final snap = await _db
        .collection('members')
        .where('cellId', isEqualTo: cellId)
        .get();
    return snap.docs.map((d) => Member.fromFirestore(d)).toList();
  }

  Future<List<Member>> getMembersByCongregation(String congregationId) async {
    final snap = await _db
        .collection('members')
        .where('congregationId', isEqualTo: congregationId)
        .where('isActive', isEqualTo: true)
        .where('isVisitor', isEqualTo: false)
        .get();
    return snap.docs.map((d) => Member.fromFirestore(d)).toList();
  }

  Future<List<Member>> searchAllActiveMembers() async {
    final snap = await _db
        .collection('members')
        .where('isActive', isEqualTo: true)
        .where('isVisitor', isEqualTo: false)
        .get();
    return snap.docs.map((d) => Member.fromFirestore(d)).toList();
  }

  Future<List<CellGroup>> getCellListByCongregation(String congregationId) async {
    final snap = await _db
        .collection('cells')
        .where('congregationId', isEqualTo: congregationId)
        .get();
    return snap.docs.map((d) => CellGroup.fromFirestore(d)).toList();
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

  // ─── People (personal data, one per person) ───

  Future<Person?> getPerson(String id) async {
    final doc = await _db.collection('people').doc(id).get();
    return doc.exists ? Person.fromFirestore(doc) : null;
  }

  Future<DocumentReference> addPerson(Person person) {
    return _db.collection('people').add(person.toMap());
  }

  Future<void> updatePerson(String id, Map<String, dynamic> data) {
    return _db.collection('people').doc(id).update(data);
  }

  /// Populates person data on a list of CellMembers
  Future<List<CellMember>> populatePersonData(List<CellMember> members) async {
    if (members.isEmpty) return members;
    final personIds = members.map((m) => m.personId).toSet();
    final personMap = <String, Person>{};
    for (final pid in personIds) {
      if (pid.isEmpty) continue;
      final doc = await _db.collection('people').doc(pid).get();
      if (doc.exists) personMap[pid] = Person.fromFirestore(doc);
    }
    for (final m in members) {
      m.person = personMap[m.personId];
    }
    return members;
  }

  /// Search people by name (all active, non-visitor across church)
  Future<List<Person>> searchAllPeople() async {
    final snap = await _db.collection('people').get();
    return snap.docs.map((d) => Person.fromFirestore(d)).toList();
  }

  // ─── Cell Members (cell-specific roles) ───

  Stream<List<CellMember>> getCellMembers({required String cellId}) {
    return _db
        .collection('cell_members')
        .where('cellId', isEqualTo: cellId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CellMember.fromFirestore(d)).toList());
  }

  Future<List<CellMember>> getCellMembersByCell(String cellId) async {
    final snap = await _db
        .collection('cell_members')
        .where('cellId', isEqualTo: cellId)
        .get();
    return snap.docs.map((d) => CellMember.fromFirestore(d)).toList();
  }

  Future<List<CellMember>> getCellMembersByCongregation(
      String congregationId) async {
    final snap = await _db
        .collection('cell_members')
        .where('congregationId', isEqualTo: congregationId)
        .where('isActive', isEqualTo: true)
        .where('isVisitor', isEqualTo: false)
        .get();
    return snap.docs.map((d) => CellMember.fromFirestore(d)).toList();
  }

  Future<List<CellMember>> searchAllActiveCellMembers() async {
    final snap = await _db
        .collection('cell_members')
        .where('isActive', isEqualTo: true)
        .where('isVisitor', isEqualTo: false)
        .get();
    return snap.docs.map((d) => CellMember.fromFirestore(d)).toList();
  }

  Future<DocumentReference> addCellMember(CellMember cellMember) {
    return _db.collection('cell_members').add(cellMember.toMap());
  }

  Future<void> updateCellMember(String id, Map<String, dynamic> data) {
    return _db.collection('cell_members').doc(id).update(data);
  }

  Future<void> deleteCellMember(String id) {
    return _db.collection('cell_members').doc(id).delete();
  }

  /// Add a person + cell_member in one operation (for new visitors/members)
  Future<String> addPersonAndCellMember({
    required Person person,
    required String cellId,
    required String supervisionId,
    required String congregationId,
    bool isVisitor = false,
    bool isLeader = false,
    bool isHelper = false,
  }) async {
    final personRef = await addPerson(person);
    final cellMember = CellMember(
      id: '',
      personId: personRef.id,
      personName: person.name,
      cellId: cellId,
      supervisionId: supervisionId,
      congregationId: congregationId,
      isVisitor: isVisitor,
      isLeader: isLeader,
      isHelper: isHelper,
    );
    final cmRef = await addCellMember(cellMember);
    return cmRef.id;
  }

  /// Add existing person to a new cell
  Future<String> addPersonToCell({
    required String personId,
    required String personName,
    required String cellId,
    required String supervisionId,
    required String congregationId,
    bool isVisitor = false,
  }) async {
    final cellMember = CellMember(
      id: '',
      personId: personId,
      personName: personName,
      cellId: cellId,
      supervisionId: supervisionId,
      congregationId: congregationId,
      isVisitor: isVisitor,
    );
    final ref = await addCellMember(cellMember);
    return ref.id;
  }

  /// Update person data and sync denormalized name to all cell_members
  Future<void> updatePersonAndSync(
      String personId, Map<String, dynamic> data) async {
    await updatePerson(personId, data);
    if (data.containsKey('name')) {
      final snap = await _db
          .collection('cell_members')
          .where('personId', isEqualTo: personId)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'personName': data['name']});
      }
      // Also update leaderName on cells where this person is leader
      final leaderSnap = await _db
          .collection('cell_members')
          .where('personId', isEqualTo: personId)
          .where('isLeader', isEqualTo: true)
          .get();
      for (final doc in leaderSnap.docs) {
        final cellId = doc.data()['cellId'];
        if (cellId != null) {
          await _db
              .collection('cells')
              .doc(cellId)
              .update({'leaderName': data['name']});
        }
      }
    }
  }

  // ─── Meetings ───

  Stream<List<Meeting>> getMeetings({
    String? cellId,
    String? supervisionId,
    String? congregationId,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('meetings');
    if (cellId != null) {
      query = query.where('cellId', isEqualTo: cellId);
    }
    if (supervisionId != null) {
      query = query.where('supervisionId', isEqualTo: supervisionId);
    }
    if (congregationId != null) {
      query = query.where('congregationId', isEqualTo: congregationId);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => Meeting.fromFirestore(d)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
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

  Future<List<Member>> getMembersByUserId(String userId) async {
    final snap = await _db
        .collection('members')
        .where('userId', isEqualTo: userId)
        .get();
    return snap.docs.map((d) => Member.fromFirestore(d)).toList();
  }

  Future<void> updateUserAndMembers(String userId, Map<String, dynamic> userData) async {
    await updateUser(userId, userData);

    // Sync to people collection (find person by userId)
    final peopleSnap = await _db
        .collection('people')
        .where('userId', isEqualTo: userId)
        .get();
    final personUpdate = <String, dynamic>{};
    if (userData.containsKey('name')) personUpdate['name'] = userData['name'];
    if (userData.containsKey('gender')) personUpdate['gender'] = userData['gender'];
    if (userData.containsKey('birthDate')) personUpdate['birthDate'] = userData['birthDate'];
    if (userData.containsKey('email')) personUpdate['email'] = userData['email'];
    if (personUpdate.isNotEmpty) {
      for (final doc in peopleSnap.docs) {
        await updatePersonAndSync(doc.id, personUpdate);
      }
    }

    // Legacy: sync to old members collection
    final members = await getMembersByUserId(userId);
    final memberUpdate = <String, dynamic>{};
    if (userData.containsKey('name')) memberUpdate['name'] = userData['name'];
    if (userData.containsKey('gender')) memberUpdate['gender'] = userData['gender'];
    if (userData.containsKey('birthDate')) memberUpdate['birthDate'] = userData['birthDate'];
    if (userData.containsKey('email')) memberUpdate['email'] = userData['email'];
    if (memberUpdate.isNotEmpty) {
      for (final m in members) {
        await updateMember(m.id, memberUpdate);
      }
    }

    // Update leaderName on cells
    if (userData.containsKey('name')) {
      final cellsSnap = await _db
          .collection('cells')
          .where('leaderId', isEqualTo: userId)
          .get();
      for (final doc in cellsSnap.docs) {
        await doc.reference.update({'leaderName': userData['name']});
      }
    }
  }
}
