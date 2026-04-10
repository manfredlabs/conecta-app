import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/church_model.dart';
import '../models/congregation_model.dart';
import '../models/supervision_model.dart';
import '../models/cell_model.dart';
import '../models/member_model.dart';
import '../models/person_model.dart';
import '../models/cell_member_model.dart';
import '../models/approval_request_model.dart';
import '../models/meeting_model.dart';
import '../models/user_model.dart';
import '../models/bulletin_model.dart';
import '../models/event_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─── Churches ───

  Future<Church?> getChurchByCode(String code) async {
    final snap = await _db
        .collection('churches')
        .where('code', isEqualTo: code.toLowerCase().trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Church.fromFirestore(snap.docs.first);
  }

  Future<Church?> getChurch(String id) async {
    final doc = await _db.collection('churches').doc(id).get();
    return doc.exists ? Church.fromFirestore(doc) : null;
  }

  Future<DocumentReference> addChurch(Church church) {
    return _db.collection('churches').add(church.toMap());
  }

  // ─── Congregations ───

  Stream<List<Congregation>> getCongregations({String? churchId}) {
    Query<Map<String, dynamic>> query = _db.collection('congregations');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    return query.snapshots().map(
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

  Stream<List<Supervision>> getSupervisions({String? congregationId, String? churchId}) {
    Query<Map<String, dynamic>> query = _db.collection('supervisions');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
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

  Future<Supervision?> getSupervision(String id) async {
    final doc = await _db.collection('supervisions').doc(id).get();
    return doc.exists ? Supervision.fromFirestore(doc) : null;
  }

  // ─── Cells ───

  Stream<List<CellGroup>> getCells({
    String? supervisionId,
    String? congregationId,
    String? leaderId,
    String? churchId,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('cells');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
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
  Future<Map<String, String>> getUserRolesByPersonId({String? churchId}) async {
    Query<Map<String, dynamic>> query = _db.collection('users');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    final snap = await query.get();
    final map = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final personId = data['personId'] as String? ?? '';
      final role = (data['role'] as String?) ?? 'leader';
      if (personId.isNotEmpty) map[personId] = role;
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

  Future<List<Member>> searchAllActiveMembers({String? churchId}) async {
    Query<Map<String, dynamic>> query = _db.collection('members')
        .where('isActive', isEqualTo: true)
        .where('isVisitor', isEqualTo: false);
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    final snap = await query.get();
    return snap.docs.map((d) => Member.fromFirestore(d)).toList();
  }

  /// Todos os membros (ativos + inativos) exceto visitantes — para aniversários
  Future<List<Person>> getAllPeopleForBirthdays({String? churchId}) async {
    Query<Map<String, dynamic>> query = _db.collection('people');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => Person.fromFirestore(d))
        .where((p) => p.birthDate != null)
        .toList();
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
  Future<List<Person>> searchAllPeople({String? churchId}) async {
    Query<Map<String, dynamic>> query = _db.collection('people');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    final snap = await query.get();
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

  Future<List<CellMember>> searchAllNonVisitorCellMembers({String? churchId}) async {
    Query<Map<String, dynamic>> query = _db.collection('cell_members')
        .where('isVisitor', isEqualTo: false);
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    final snap = await query.get();
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

  // ─── Member History ───

  Future<void> addMemberHistory({
    required String cellMemberId,
    required String action,
    String? from,
    String? to,
    required String changedBy,
    String cellId = '',
  }) {
    return _db
        .collection('cell_members')
        .doc(cellMemberId)
        .collection('history')
        .add({
      'action': action,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      'changedBy': changedBy,
      if (cellId.isNotEmpty) 'cellId': cellId,
      'date': FieldValue.serverTimestamp(),
    });
  }

  /// Add a person + cell_member in one operation (for new visitors/members)
  Future<String> addPersonAndCellMember({
    required Person person,
    required String cellId,
    required String supervisionId,
    required String congregationId,
    String? churchId,
    bool isVisitor = false,
    bool isLeader = false,
    bool isHelper = false,
    String changedBy = '',
  }) async {
    final personRef = await addPerson(person);
    final cellMember = CellMember(
      id: '',
      personId: personRef.id,
      personName: person.name,
      cellId: cellId,
      supervisionId: supervisionId,
      congregationId: congregationId,
      churchId: churchId,
      isVisitor: isVisitor,
      isLeader: isLeader,
      isHelper: isHelper,
    );
    final cmRef = await addCellMember(cellMember);
    if (changedBy.isNotEmpty) {
      await addMemberHistory(
        cellMemberId: cmRef.id,
        action: 'joined',
        changedBy: changedBy,
        cellId: cellId,
      );
    }
    return cmRef.id;
  }

  /// Add existing person to a new cell
  Future<String> addPersonToCell({
    required String personId,
    required String personName,
    required String cellId,
    required String supervisionId,
    required String congregationId,
    String? churchId,
    bool isVisitor = false,
    String changedBy = '',
  }) async {
    final cellMember = CellMember(
      id: '',
      personId: personId,
      personName: personName,
      cellId: cellId,
      supervisionId: supervisionId,
      congregationId: congregationId,
      churchId: churchId,
      isVisitor: isVisitor,
    );
    final ref = await addCellMember(cellMember);
    if (changedBy.isNotEmpty) {
      await addMemberHistory(
        cellMemberId: ref.id,
        action: 'joined',
        changedBy: changedBy,
        cellId: cellId,
      );
    }
    return ref.id;
  }

  /// Update person data and sync denormalized name to all cell_members
  Future<void> updatePersonAndSync(
      String personId, Map<String, dynamic> data) async {
    await updatePerson(personId, data);

    // Get person's userId for syncing to users collection
    final personDoc = await _db.collection('people').doc(personId).get();
    final userId = personDoc.data()?['userId'] as String?;

    // Sync relevant fields to users collection
    if (userId != null) {
      final userUpdate = <String, dynamic>{};
      if (data.containsKey('name')) userUpdate['name'] = data['name'];
      if (data.containsKey('gender')) userUpdate['gender'] = data['gender'];
      if (data.containsKey('birthDate')) userUpdate['birthDate'] = data['birthDate'];
      if (data.containsKey('email')) userUpdate['email'] = data['email'];
      if (userUpdate.isNotEmpty) {
        await _db.collection('users').doc(userId).update(userUpdate);
      }
    }

    if (data.containsKey('name')) {
      final newName = data['name'] as String;

      // Sync to all cell_members with this personId
      final snap = await _db
          .collection('cell_members')
          .where('personId', isEqualTo: personId)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'personName': newName});
      }

      if (userId != null) {
        // Sync leaderName on cells where this person is MAIN leader
        final cellsSnap = await _db
            .collection('cells')
            .where('leaderId', isEqualTo: userId)
            .get();
        for (final doc in cellsSnap.docs) {
          await doc.reference.update({'leaderName': newName});
        }

        // Sync supervisorName on supervisions where this person is supervisor
        final supSnap = await _db
            .collection('supervisions')
            .where('supervisorId', isEqualTo: userId)
            .get();
        for (final doc in supSnap.docs) {
          await doc.reference.update({'supervisorName': newName});
        }

        // Sync pastorName on congregations where this person is pastor
        final congSnap = await _db
            .collection('congregations')
            .where('pastorId', isEqualTo: userId)
            .get();
        for (final doc in congSnap.docs) {
          await doc.reference.update({'pastorName': newName});
        }
      }
    }
  }

  // ─── Meetings ───

  Stream<List<Meeting>> getMeetings({
    String? cellId,
    String? supervisionId,
    String? congregationId,
    String? churchId,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('meetings');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
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

  Stream<List<AppUser>> getUsers({String? churchId}) {
    Query<Map<String, dynamic>> query = _db.collection('users');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    return query.snapshots().map(
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

      // Update supervisorName on supervisions
      final supSnap = await _db
          .collection('supervisions')
          .where('supervisorId', isEqualTo: userId)
          .get();
      for (final doc in supSnap.docs) {
        await doc.reference.update({'supervisorName': userData['name']});
      }

      // Update pastorName on congregations
      final congSnap = await _db
          .collection('congregations')
          .where('pastorId', isEqualTo: userId)
          .get();
      for (final doc in congSnap.docs) {
        await doc.reference.update({'pastorName': userData['name']});
      }
    }
  }

  // ─── Approval Requests ───

  Stream<List<ApprovalRequest>> getPendingApprovalRequests({String? churchId}) {
    Query<Map<String, dynamic>> query = _db
        .collection('approval_requests')
        .where('status', isEqualTo: 'pending');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    return query.snapshots().map((snap) {
      final list =
          snap.docs.map((d) => ApprovalRequest.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<bool> hasPendingRequest(String cellMemberId) async {
    final snap = await _db
        .collection('approval_requests')
        .where('cellMemberId', isEqualTo: cellMemberId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> createApprovalRequest(ApprovalRequest request) async {
    await _db.collection('approval_requests').add(request.toMap());
  }

  Future<void> approveRequest(String requestId, {required String changedBy}) async {
    final doc = await _db.collection('approval_requests').doc(requestId).get();
    if (!doc.exists) return;

    final request = ApprovalRequest.fromFirestore(doc);

    // Execute promotion: visitor → member + baptized
    await _db.collection('cell_members').doc(request.cellMemberId).update({
      'isVisitor': false,
    });

    if (request.personId.isNotEmpty) {
      await _db.collection('people').doc(request.personId).update({
        'baptized': true,
      });
    }

    // Mark as approved
    await _db.collection('approval_requests').doc(requestId).update({
      'status': 'approved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': changedBy,
    });

    // Track history
    await addMemberHistory(
      cellMemberId: request.cellMemberId,
      action: 'approval_approved',
      changedBy: changedBy,
      cellId: request.cellId,
    );
    await addMemberHistory(
      cellMemberId: request.cellMemberId,
      action: 'role_change',
      from: 'visitor',
      to: 'member',
      changedBy: changedBy,
      cellId: request.cellId,
    );
  }

  Future<void> rejectRequest(String requestId, {required String changedBy}) async {
    final doc = await _db.collection('approval_requests').doc(requestId).get();
    if (!doc.exists) return;

    final request = ApprovalRequest.fromFirestore(doc);

    await _db.collection('approval_requests').doc(requestId).update({
      'status': 'rejected',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': changedBy,
    });

    await addMemberHistory(
      cellMemberId: request.cellMemberId,
      action: 'approval_rejected',
      changedBy: changedBy,
      cellId: request.cellId,
    );
  }

  /// Cancel all pending requests for a cell member (e.g. when inactivated/deleted)
  Future<void> cancelPendingRequests(String cellMemberId, {String changedBy = ''}) async {
    final snap = await _db
        .collection('approval_requests')
        .where('cellMemberId', isEqualTo: cellMemberId)
        .where('status', isEqualTo: 'pending')
        .get();
    String cellId = '';
    for (final doc in snap.docs) {
      await doc.reference.update({
        'status': 'cancelled',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      if (cellId.isEmpty) {
        cellId = (doc.data()['cellId'] as String?) ?? '';
      }
    }
    if (snap.docs.isNotEmpty && changedBy.isNotEmpty) {
      await addMemberHistory(
        cellMemberId: cellMemberId,
        action: 'approval_cancelled',
        changedBy: changedBy,
        cellId: cellId,
      );
    }
  }

  // ─── Bulletins ───

  Stream<List<Bulletin>> getBulletins({String? churchId}) {
    Query<Map<String, dynamic>> query = _db.collection('bulletins');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => Bulletin.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<String> addBulletin(Bulletin bulletin) async {
    final ref = await _db.collection('bulletins').add(bulletin.toMap());
    return ref.id;
  }

  Future<void> deleteBulletin(String bulletinId) async {
    final doc = await _db.collection('bulletins').doc(bulletinId).get();
    if (!doc.exists) return;
    final bulletin = Bulletin.fromFirestore(doc);

    // Delete file from Storage
    if (bulletin.storagePath.isNotEmpty) {
      try {
        await _storage.ref(bulletin.storagePath).delete();
      } catch (_) {
        // File might already be deleted
      }
    }

    await _db.collection('bulletins').doc(bulletinId).delete();
  }

  /// Upload file to Firebase Storage and return (downloadUrl, storagePath)
  Future<(String url, String path)> uploadBulletinFile({
    required String churchId,
    required String bulletinId,
    required String fileName,
    required File file,
  }) async {
    final storagePath = 'churches/$churchId/bulletins/$bulletinId/$fileName';
    final ref = _storage.ref(storagePath);
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    return (url, storagePath);
  }

  Future<void> updateBulletinUrls({
    required String bulletinId,
    required String fileUrl,
    required String storagePath,
  }) async {
    await _db.collection('bulletins').doc(bulletinId).update({
      'fileUrl': fileUrl,
      'storagePath': storagePath,
    });
  }

  Future<void> updateBulletinTitle({
    required String bulletinId,
    required String title,
  }) async {
    await _db.collection('bulletins').doc(bulletinId).update({
      'title': title,
    });
  }

  /// Referência direta ao Storage para download
  Reference storageRef(String path) => _storage.ref(path);

  // ─── Events (Agenda) ───

  Stream<List<ChurchEvent>> getEvents({String? churchId}) {
    Query<Map<String, dynamic>> query = _db.collection('events');
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => ChurchEvent.fromFirestore(d)).toList();
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return list;
    });
  }

  Future<String> addEvent(ChurchEvent event) async {
    final ref = await _db.collection('events').add(event.toMap());
    return ref.id;
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    await _db.collection('events').doc(eventId).update(data);
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.collection('events').doc(eventId).delete();
  }
}
