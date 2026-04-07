import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _appUser;
  bool _isLoading = false;
  String? _error;

  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _appUser != null;
  String? get error => _error;
  User? get firebaseUser => _authService.currentUser;

  Future<void> init() async {
    final user = _authService.currentUser;
    if (user != null) {
      _appUser = await _authService.getAppUser(user.uid);
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _appUser = await _authService.signIn(email, password);
      if (_appUser == null) {
        _error = 'Usuário não encontrado no sistema.';
      }
      return _appUser != null;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      return false;
    } catch (e) {
      _error = 'Erro inesperado. Tente novamente.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _appUser = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      _appUser = await _authService.getAppUser(user.uid);
      notifyListeners();
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'E-mail não encontrado.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Senha incorreta.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-disabled':
        return 'Conta desativada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um momento.';
      default:
        return 'Erro ao fazer login. Tente novamente.';
    }
  }
}
