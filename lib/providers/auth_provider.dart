import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _appUser;
  String? _churchId;
  bool _isLoading = false;
  String? _error;

  AppUser? get appUser => _appUser;
  String? get churchId => _churchId ?? _appUser?.churchId;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _appUser != null;
  String? get error => _error;
  User? get firebaseUser => _authService.currentUser;
  bool get hasChurch => churchId != null && churchId!.isNotEmpty;

  Future<void> init() async {
    // Load saved churchId from local storage
    _churchId = await _authService.getSavedChurchId();

    final user = _authService.currentUser;
    if (user != null) {
      _appUser = await _authService.getAppUser(user.uid);
      if (_appUser?.churchId != null) {
        _churchId = _appUser!.churchId;
      }
      notifyListeners();
    }
  }

  void setChurchId(String churchId) {
    _churchId = churchId;
    _authService.saveChurchId(churchId);
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _appUser = await _authService.signIn(email, password);
      if (_appUser == null) {
        _error = 'Usuário não encontrado no sistema.';
      } else if (_appUser!.churchId != null) {
        _churchId = _appUser!.churchId;
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
    _churchId = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      _appUser = await _authService.getAppUser(user.uid);
      if (_appUser?.churchId != null) {
        _churchId = _appUser!.churchId;
      }
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
