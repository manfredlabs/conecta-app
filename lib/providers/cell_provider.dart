import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cell_model.dart';
import '../models/member_model.dart';
import '../models/cell_member_model.dart';
import '../models/person_model.dart';
import '../models/meeting_model.dart';
import '../services/firestore_service.dart';

class CellProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<CellGroup> _cells = [];
  List<Member> _members = [];
  List<CellMember> _cellMembers = [];
  List<Meeting> _meetings = [];
  CellGroup? _selectedCell;
  bool _isLoading = false;

  StreamSubscription? _cellsSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _cellMembersSub;
  StreamSubscription? _meetingsSub;

  List<CellGroup> get cells => _cells;
  List<Member> get members => _members;
  List<CellMember> get cellMembers => _cellMembers;
  List<Meeting> get meetings => _meetings;
  CellGroup? get selectedCell => _selectedCell;
  bool get isLoading => _isLoading;

  void selectCell(CellGroup cell) {
    _selectedCell = cell;
    notifyListeners();
    listenToMembers(cell.id);
    listenToCellMembers(cell.id);
    listenToMeetings(cell.id);
    _ensureLeaderAsCellMember(cell);
  }

  Future<void> _ensureLeaderAsCellMember(CellGroup cell) async {
    if (cell.leaderId == null || cell.leaderName == null) return;

    final snap = await _firestoreService.getCellMembersByCell(cell.id);
    final hasLeader = snap.any((m) => m.isLeader);
    if (!hasLeader) {
      await _firestoreService.addCellMember(CellMember(
        id: '',
        personId: '',
        personName: cell.leaderName!,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: cell.congregationId,
        isLeader: true,
      ));
    }
  }

  void listenToCells({
    String? supervisionId,
    String? congregationId,
    String? leaderId,
  }) {
    _cellsSub?.cancel();
    _cellsSub = _firestoreService
        .getCells(
          supervisionId: supervisionId,
          congregationId: congregationId,
          leaderId: leaderId,
        )
        .listen((cells) {
      _cells = cells;
      // Atualizar selectedCell se ela mudou no Firestore
      if (_selectedCell != null) {
        final updated = cells.where((c) => c.id == _selectedCell!.id);
        if (updated.isNotEmpty) {
          _selectedCell = updated.first;
        }
      }
      notifyListeners();
    });
  }

  void listenToMembers(String cellId) {
    _membersSub?.cancel();
    _membersSub = _firestoreService.getMembers(cellId: cellId).listen((members) {
      _members = members;
      notifyListeners();
    });
  }

  void listenToCellMembers(String cellId) {
    _cellMembersSub?.cancel();
    _cellMembersSub = _firestoreService.getCellMembers(cellId: cellId).listen((members) async {
      _cellMembers = await _firestoreService.populatePersonData(members);
      notifyListeners();
    });
  }

  void listenToMeetings(String cellId) {
    _meetingsSub?.cancel();
    _meetingsSub = _firestoreService.getMeetings(cellId: cellId).listen((meetings) {
      _meetings = meetings;
      notifyListeners();
    });
  }

  Future<String?> addMember(Member member) async {
    _isLoading = true;
    notifyListeners();
    try {
      final docRef = await _firestoreService.addMember(member);
      return docRef.id;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── New CellMember CRUD ───

  Future<String?> addNewCellMember(CellMember cellMember) async {
    _isLoading = true;
    notifyListeners();
    try {
      final docRef = await _firestoreService.addCellMember(cellMember);
      return docRef.id;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addPersonAndCellMember({
    required Person person,
    required String cellId,
    required String supervisionId,
    required String congregationId,
    bool isVisitor = false,
    bool isLeader = false,
    bool isHelper = false,
    String changedBy = '',
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final cmId = await _firestoreService.addPersonAndCellMember(
        person: person,
        cellId: cellId,
        supervisionId: supervisionId,
        congregationId: congregationId,
        isVisitor: isVisitor,
        isLeader: isLeader,
        isHelper: isHelper,
        changedBy: changedBy,
      );
      return cmId;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCellMember(String id, Map<String, dynamic> data) async {
    await _firestoreService.updateCellMember(id, data);

    if (data.containsKey('personName') || data.containsKey('isLeader')) {
      final member = _cellMembers.where((m) => m.id == id).firstOrNull;
      if (member != null && member.isLeader && _selectedCell != null) {
        if (data.containsKey('personName')) {
          await _firestoreService.updateCell(
            _selectedCell!.id,
            {'leaderName': data['personName']},
          );
        }
      }
    }
  }

  Future<void> deleteCellMember(String id) async {
    await _firestoreService.deleteCellMember(id);
  }

  Future<void> updatePersonAndSync(String personId, Map<String, dynamic> data) async {
    await _firestoreService.updatePersonAndSync(personId, data);
  }

  Future<void> deleteMember(String id) async {
    await _firestoreService.deleteMember(id);
  }

  Future<void> updateMember(String id, Map<String, dynamic> data) async {
    await _firestoreService.updateMember(id, data);

    // Se o nome do líder mudou, propagar pra célula e user
    if (data.containsKey('name')) {
      final member = _members.where((m) => m.id == id).firstOrNull;
      if (member != null && member.isLeader && _selectedCell != null) {
        await _firestoreService.updateCell(
          _selectedCell!.id,
          {'leaderName': data['name']},
        );
        if (_selectedCell!.leaderId != null) {
          await _firestoreService.updateUser(
            _selectedCell!.leaderId!,
            {'name': data['name']},
          );
        }
      }
    }
  }

  Future<void> updateCell(String id, Map<String, dynamic> data) async {
    await _firestoreService.updateCell(id, data);
    if (_selectedCell != null && _selectedCell!.id == id) {
      _selectedCell = _selectedCell!.copyWith(
        name: data['name'] as String?,
        meetingDay: data['meetingDay'] as String?,
        meetingTime: data['meetingTime'] as String?,
        address: data['address'] as String?,
      );
      notifyListeners();
    }
  }

  Future<void> addMeeting(Meeting meeting) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.addMeeting(meeting);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMeeting(String id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateMeeting(id, data);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMeeting(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.deleteMeeting(id);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cellsSub?.cancel();
    _membersSub?.cancel();
    _cellMembersSub?.cancel();
    _meetingsSub?.cancel();
    super.dispose();
  }
}
