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
  bool _isBiometricAuthenticated = false;
  int _biometricFailCount = 0;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isBiometricAuthenticated => _isBiometricAuthenticated;
  bool get biometricLockedOut => _biometricFailCount >= 3;

  AuthViewModel() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    _user = await _authRepository.getCurrentUserModel();
    // Initially, if no user or biometrics are disabled, we don't need biometric check
    if (_user == null || !_user!.biometricEnabled) {
      _isBiometricAuthenticated = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authRepository.login(email, password);
      if (_user != null) {
        // After fresh login, we are authenticated for biometrics
        _isBiometricAuthenticated = true;
        _biometricFailCount = 0;
      }
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
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _biometricFailCount = 0;
      }
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
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _biometricFailCount = 0;
      }
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

  Future<void> refreshUser() async {
    _user = await _authRepository.getCurrentUserModel();
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepository.signOut();
    _user = null;
    _isBiometricAuthenticated = false;
    _biometricFailCount = 0;
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
      if (!enabled) {
        _isBiometricAuthenticated = true;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (_user == null || !_user!.biometricEnabled) return false;
    
    bool success = await _localAuthService.authenticate();
    if (success) {
      _isBiometricAuthenticated = true;
      _biometricFailCount = 0;
    } else {
      _biometricFailCount++;
    }
    notifyListeners();
    return success;
  }

  void resetBiometricAuth() {
    _isBiometricAuthenticated = false;
    _biometricFailCount = 0;
    notifyListeners();
  }
}
