import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _churchIdKey = 'selected_church_id';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Church persistence ───

  Future<String?> getSavedChurchId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_churchIdKey);
  }

  Future<void> saveChurchId(String churchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_churchIdKey, churchId);
  }

  Future<void> clearChurchId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_churchIdKey);
  }

  // ─── Auth ───

  Future<AppUser?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user != null) {
      return getAppUser(credential.user!.uid);
    }
    return null;
  }

  Future<void> signOut() async {
    await clearChurchId();
    await _auth.signOut();
  }

  Future<AppUser?> getAppUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      var appUser = AppUser.fromFirestore(doc);

      // Save churchId to local storage
      if (appUser.churchId != null) {
        await saveChurchId(appUser.churchId!);
      }

      // Resolve personId from people collection
      if (appUser.personId == null) {
        final personSnap = await _firestore
            .collection('people')
            .where('userId', isEqualTo: uid)
            .limit(1)
            .get();
        if (personSnap.docs.isNotEmpty) {
          final resolvedPersonId = personSnap.docs.first.id;
          // Persist back to Firestore for future lookups
          await _firestore.collection('users').doc(uid).update({
            'personId': resolvedPersonId,
          });
          appUser = AppUser(
            id: appUser.id,
            name: appUser.name,
            email: appUser.email,
            role: appUser.role,
            churchId: appUser.churchId,
            congregationId: appUser.congregationId,
            supervisionId: appUser.supervisionId,
            cellId: appUser.cellId,
            personId: resolvedPersonId,
            gender: appUser.gender,
            birthDate: appUser.birthDate,
          );
        }
      }

      // Load supervised supervision IDs
      final supsSnap = await _firestore
          .collection('supervisions')
          .where('supervisorId', isEqualTo: uid)
          .get();
      final supIds = supsSnap.docs.map((d) => d.id).toList();

      if (supIds.isNotEmpty) {
        appUser = AppUser(
          id: appUser.id,
          name: appUser.name,
          email: appUser.email,
          role: appUser.role,
          churchId: appUser.churchId,
          congregationId: appUser.congregationId,
          supervisionId: appUser.supervisionId,
          cellId: appUser.cellId,
          personId: appUser.personId,
          gender: appUser.gender,
          birthDate: appUser.birthDate,
          supervisedSupervisionIds: supIds,
        );
      }

      return appUser;
    }
    return null;
  }

  Future<AppUser> createUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? churchId,
    String? congregationId,
    String? supervisionId,
    String? cellId,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = AppUser(
      id: credential.user!.uid,
      name: name,
      email: email,
      role: role,
      churchId: churchId,
      congregationId: congregationId,
      supervisionId: supervisionId,
      cellId: cellId,
    );
    await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .set(user.toMap());
    return user;
  }
}
