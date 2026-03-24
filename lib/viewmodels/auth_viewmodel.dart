import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../services/local_auth_service.dart';
import '../services/firestore_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final LocalAuthService _localAuthService = LocalAuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthViewModel() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    _user = await _authRepository.getCurrentUserModel();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authRepository.login(email, password);
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName, int age, double weight) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authRepository.register(email, password, fullName, age, weight);
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authRepository.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.signOut();
    _user = null;
    notifyListeners();
  }

  Future<bool> toggleBiometrics(bool enabled) async {
    if (_user == null) return false;
    
    if (enabled) {
      bool success = await _localAuthService.authenticate();
      if (!success) return false;
    }

    try {
      await _firestoreService.updateBiometricStatus(_user!.uid, enabled);
      _user = _user!.copyWith(biometricEnabled: enabled);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (_user == null || !_user!.biometricEnabled) return false;
    return await _localAuthService.authenticate();
  }
}
