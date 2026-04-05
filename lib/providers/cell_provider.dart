import 'package:flutter/material.dart';
import '../models/cell_model.dart';
import '../models/member_model.dart';
import '../models/meeting_model.dart';
import '../services/firestore_service.dart';

class CellProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<CellGroup> _cells = [];
  List<Member> _members = [];
  List<Meeting> _meetings = [];
  CellGroup? _selectedCell;
  bool _isLoading = false;

  List<CellGroup> get cells => _cells;
  List<Member> get members => _members;
  List<Meeting> get meetings => _meetings;
  CellGroup? get selectedCell => _selectedCell;
  bool get isLoading => _isLoading;

  void selectCell(CellGroup cell) {
    _selectedCell = cell;
    notifyListeners();
    listenToMembers(cell.id);
    listenToMeetings(cell.id);
  }

  void listenToCells({
    String? supervisionId,
    String? congregationId,
    String? leaderId,
  }) {
    _firestoreService
        .getCells(
          supervisionId: supervisionId,
          congregationId: congregationId,
          leaderId: leaderId,
        )
        .listen((cells) {
      _cells = cells;
      notifyListeners();
    });
  }

  void listenToMembers(String cellId) {
    _firestoreService.getMembers(cellId: cellId).listen((members) {
      _members = members;
      notifyListeners();
    });
  }

  void listenToMeetings(String cellId) {
    _firestoreService.getMeetings(cellId: cellId).listen((meetings) {
      _meetings = meetings;
      notifyListeners();
    });
  }

  Future<void> addMember(Member member) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.addMember(member);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMember(String id) async {
    await _firestoreService.deleteMember(id);
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
}
