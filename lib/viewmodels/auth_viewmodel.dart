import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../services/local_auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/env_config.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final LocalAuthService _localAuthService = LocalAuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

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
    
    // Check local storage for biometric preference
    final bioEnabled = await _storageService.read('biometric_enabled');
    
    // Initially, if no user or biometrics are disabled, we don't need biometric check
    if (_user == null || bioEnabled != 'true') {
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

  Future<bool> register(String email, String password, String fullName, int age, double weight, {Uint8List? profileImageData}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authRepository.register(email, password, fullName, age, weight, profileImageData: profileImageData);
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
    await _storageService.delete('biometric_enabled');
    _user = null;
    _isBiometricAuthenticated = false;
    _biometricFailCount = 0;
    notifyListeners();
  }

  Future<bool> toggleBiometrics(bool enabled) async {
    if (_user == null) return false;
    _error = null;
    
    if (enabled) {
      try {
        debugPrint("Attempting to toggle biometrics ON. Authenticating...");
        bool success = await _localAuthService.authenticate();
        if (!success) {
          _error = "Authentication failed. Ensure you have a PIN/Fingerprint set up.";
          notifyListeners();
          return false;
        }
      } catch (e) {
        _error = "Hardware Error: ${e.toString()}";
        notifyListeners();
        return false;
      }
    }

    try {
      debugPrint("Saving biometric status to Firestore/Storage: $enabled");
      await _firestoreService.updateBiometricStatus(_user!.uid, enabled);
      await _storageService.save('biometric_enabled', enabled.toString());
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
    // If we don't have a user in memory yet (e.g. fresh refresh), try to get it
    if (_user == null) {
      _user = await _authRepository.getCurrentUserModel();
    }
    
    // We still check local storage as the source of truth for the device preference
    final bioEnabled = await _storageService.read('biometric_enabled');
    if (bioEnabled != 'true') return false;
    
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

  Future<bool> verifyPassword(String password) async {
    if (_user == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Re-authenticating using login repository logic
      final result = await _authRepository.login(_user!.email, password);
      if (result != null) {
        _isBiometricAuthenticated = true;
        _biometricFailCount = 0;
      }
      _isLoading = false;
      notifyListeners();
      return result != null;
    } catch (e) {
      _error = "Invalid password. Please try again.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void resetBiometricAuth() {
    _isBiometricAuthenticated = false;
    _biometricFailCount = 0;
    notifyListeners();
  }
}
