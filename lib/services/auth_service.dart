import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
    await _auth.signOut();
  }

  Future<AppUser?> getAppUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final appUser = AppUser.fromFirestore(doc);
      // Resolve personId from people collection
      if (appUser.personId == null) {
        final personSnap = await _firestore
            .collection('people')
            .where('userId', isEqualTo: uid)
            .limit(1)
            .get();
        if (personSnap.docs.isNotEmpty) {
          return AppUser(
            id: appUser.id,
            name: appUser.name,
            email: appUser.email,
            role: appUser.role,
            congregationId: appUser.congregationId,
            supervisionId: appUser.supervisionId,
            cellId: appUser.cellId,
            personId: personSnap.docs.first.id,
            gender: appUser.gender,
            birthDate: appUser.birthDate,
          );
        }
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
