import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/congregation_model.dart';
import '../models/supervision_model.dart';
import '../services/firestore_service.dart';

class HierarchyProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Congregation> _congregations = [];
  List<Supervision> _supervisions = [];
  Congregation? _selectedCongregation;
  Supervision? _selectedSupervision;

  StreamSubscription? _congregationsSub;
  StreamSubscription? _supervisionsSub;

  List<Congregation> get congregations => _congregations;
  List<Supervision> get supervisions => _supervisions;
  Congregation? get selectedCongregation => _selectedCongregation;
  Supervision? get selectedSupervision => _selectedSupervision;

  void listenToCongregations({String? churchId}) {
    _congregationsSub?.cancel();
    _congregationsSub =
        _firestoreService.getCongregations(churchId: churchId).listen((list) {
      _congregations = list;
      notifyListeners();
    });
  }

  void listenToSupervisions({String? congregationId, String? churchId}) {
    _supervisionsSub?.cancel();
    _supervisionsSub = _firestoreService
        .getSupervisions(congregationId: congregationId, churchId: churchId)
        .listen((list) {
      _supervisions = list;
      notifyListeners();
    });
  }

  void selectCongregation(Congregation congregation) {
    _selectedCongregation = congregation;
    notifyListeners();
    listenToSupervisions(congregationId: congregation.id);
  }

  Future<void> updateCongregation(String id, Map<String, dynamic> data) async {
    await _firestoreService.updateCongregation(id, data);
    // Re-fetch to update selectedCongregation
    final updated = await _firestoreService.getCongregation(id);
    if (updated != null) {
      _selectedCongregation = updated;
      notifyListeners();
    }
  }

  void selectSupervision(Supervision supervision) {
    _selectedSupervision = supervision;
    notifyListeners();
  }

  Future<void> updateSupervision(String id, Map<String, dynamic> data) async {
    await _firestoreService.updateSupervision(id, data);
    // Re-fetch to update selectedSupervision
    final doc = await FirebaseFirestore.instance.collection('supervisions').doc(id).get();
    if (doc.exists) {
      _selectedSupervision = Supervision.fromFirestore(doc);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _congregationsSub?.cancel();
    _supervisionsSub?.cancel();
    super.dispose();
  }
}
