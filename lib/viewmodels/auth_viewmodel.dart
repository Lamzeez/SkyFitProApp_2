import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:typed_data';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../services/local_auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/env_config.dart';
import 'dart:math';
import '../services/email_service.dart';

// Import the web helper functions (loadCredentialId, getLastRegisteredCredentialId,
// getStoredRpId). On mobile the conditional import resolves to the stub which
// provides no-op versions of all three, so this is safe on all platforms.
import '../services/local_auth_service_web.dart'
    if (dart.library.io) '../services/local_auth_service_stub.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final LocalAuthService _localAuthService = LocalAuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _success;
  bool _isBiometricAuthenticated = false;
  bool _isPinAuthenticated = false;
  int _biometricFailCount = 0;
  Timer? _errorTimer;
  Timer? _successTimer;

  String? _currentOTP;
  Map<String, dynamic>? _pendingRegistrationData;
  DateTime? _otpSentTime;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get success => _success;
  bool get isBiometricAuthenticated => _isBiometricAuthenticated;
  bool get isPinAuthenticated => _isPinAuthenticated;
  bool get biometricLockedOut => _biometricFailCount >= 3;
  bool get pinEnabled =>
      _user?.securePin != null && _user!.securePin!.isNotEmpty;

  AuthViewModel() {
    _init();
  }

  // ── Message helpers ───────────────────────────────────────────────────────

  void setError(String message, {double seconds = 2.8}) {
    _errorTimer?.cancel();
    _error = message;
    _errorTimer = Timer(Duration(milliseconds: (seconds * 1000).toInt()), () {
      _error = null;
      notifyListeners();
    });
  }

  void clearError() {
    _error = null;
    _errorTimer?.cancel();
    notifyListeners();
  }

  void setSuccess(String message, {double seconds = 2.8}) {
    _successTimer?.cancel();
    _success = message;
    _successTimer = Timer(Duration(milliseconds: (seconds * 1000).toInt()), () {
      _success = null;
      notifyListeners();
    });
  }

  void clearSuccess() {
    _success = null;
    _successTimer?.cancel();
    notifyListeners();
  }

  // ── OTP / Registration ────────────────────────────────────────────────────

  Future<bool> sendOTPForRegistration(
      String email, Map<String, dynamic> registrationData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      bool isTaken = await _firestoreService.isEmailTaken(email);
      if (isTaken) {
        setError("An account already exists for this email.");
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final otp =
          (100000 + Random().nextInt(900000)).toString();
      bool sent = await EmailService.sendOTP(email, otp);
      if (sent) {
        _currentOTP = otp;
        _pendingRegistrationData = registrationData;
        _otpSentTime = DateTime.now();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        setError("Failed to send verification code. Please try again.");
      }
    } catch (e) {
      setError(e.toString());
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> verifyOTPAndRegister(String enteredOTP) async {
    if (_currentOTP == null || _pendingRegistrationData == null) {
      setError("Session expired. Please register again.");
      return false;
    }
    if (enteredOTP != _currentOTP) {
      setError("Invalid verification code. Please check and try again.");
      return false;
    }
    if (DateTime.now().difference(_otpSentTime!).inMinutes > 10) {
      setError("Verification code expired. Please request a new one.");
      return false;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final data = _pendingRegistrationData!;
      bool success = await register(
        data['email'], data['password'], data['fullName'],
        data['age'], data['weight'], data['height'],
        profileImageData: data['profileImageData'],
      );
      if (success) {
        _currentOTP = null;
        _pendingRegistrationData = null;
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendOTP() async {
    if (_pendingRegistrationData == null) return false;
    return sendOTPForRegistration(
        _pendingRegistrationData!['email'], _pendingRegistrationData!);
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    _user = await _authRepository.getCurrentUserModel();
    final bioEnabled = await _storageService.read('biometric_enabled');
    if (_user == null || (bioEnabled != 'true' && !pinEnabled)) {
      _isBiometricAuthenticated = true;
      _isPinAuthenticated = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    _success = null;
    notifyListeners();
    try {
      _user = await _authRepository.login(email, password);
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
        await _storageService.save('bio_email', email);
        await _storageService.save('bio_password', password);
        setSuccess("Welcome back, ${_user!.fullName}!");
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String email, String password, String fullName,
    int age, double weight, double height, {
    Uint8List? profileImageData,
  }) async {
    _isLoading = true;
    _error = null;
    _success = null;
    notifyListeners();
    try {
      _user = await _authRepository.register(
        email, password, fullName, age, weight, height,
        profileImageData: profileImageData,
      );
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
        setSuccess("Account created successfully!");
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    _success = null;
    notifyListeners();
    try {
      _user = await _authRepository.signInWithGoogle();
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
        setSuccess("Signed in with Google successfully!");
      } else {
        setError("Sign-in with Google was cancelled. Please try again.");
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithFacebook() async {
    _isLoading = true;
    _error = null;
    _success = null;
    notifyListeners();
    try {
      _user = await _authRepository.signInWithFacebook();
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
        setSuccess("Signed in with Facebook successfully!");
      } else {
        setError("Sign-in with Facebook was cancelled. Please try again.");
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authRepository.deleteAccount();
      _user = null;
      _isBiometricAuthenticated = false;
      _isPinAuthenticated = false;
      _biometricFailCount = 0;
      setSuccess("Your account has been permanently deleted.");
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('requires-recent-login')) {
        setError("For security, please log in again before deleting your account.");
      } else {
        setError(msg);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshUser() async {
    _user = await _authRepository.getCurrentUserModel();
    notifyListeners();
  }

  Future<void> logout({bool showSuccess = true}) async {
    await _authRepository.signOut();
    await _storageService.delete('biometric_enabled');
    await _storageService.delete('bio_email');
    await _storageService.delete('bio_password');
    _user = null;
    _isBiometricAuthenticated = false;
    _isPinAuthenticated = false;
    _biometricFailCount = 0;
    if (showSuccess) setSuccess("Logged out successfully.");
    notifyListeners();
  }

  // ── Biometrics ────────────────────────────────────────────────────────────

  Future<bool> toggleBiometrics(bool enabled) async {
    if (_user == null) return false;
    _error = null;

    if (enabled) {
      // 1. Check the browser supports WebAuthn
      bool available = await _localAuthService.isBiometricAvailable();
      if (!available) {
        setError(
          kIsWeb
              ? "Your browser does not support biometric login. "
                "Use Chrome, Edge, or Safari on a modern device."
              : "Biometrics not available. Enroll a fingerprint in settings first.",
          seconds: 6,
        );
        notifyListeners();
        return false;
      }

      // 2. Trigger the OS fingerprint registration prompt
      bool registered = await _localAuthService.registerBiometric(
        _user!.uid,
        _user!.fullName,
      );
      if (!registered) {
        setError(
          kIsWeb
              ? "Fingerprint setup was cancelled, or no fingerprint is enrolled "
                "on this device. Go to phone Settings → Security → Fingerprint and "
                "add one, then try again."
              : "Biometric setup failed. Please try again.",
          seconds: 8,
        );
        notifyListeners();
        return false;
      }

      // 3. Save the credential ID to Firestore so it survives Incognito sessions.
      //    getLastRegisteredCredentialId() and getStoredRpId() are both defined
      //    in local_auth_service_web.dart (and no-ops in the stub).
      if (kIsWeb) {
        final credentialId = getLastRegisteredCredentialId();
        final rpId = getStoredRpId();
        if (credentialId != null && credentialId.isNotEmpty) {
          await _firestoreService.saveWebAuthnCredentialId(
              _user!.uid, credentialId, rpId);
          debugPrint('[AuthVM] Credential ID saved to Firestore: $credentialId');
        }
      }
    } else {
      // Disabling — remove the credential from Firestore
      if (kIsWeb) {
        await _firestoreService.clearWebAuthnCredential(_user!.uid);
      }
    }

    // 4. Persist the enabled flag
    try {
      await _firestoreService.updateBiometricStatus(_user!.uid, enabled);
      await _storageService.save('biometric_enabled', enabled.toString());
      _user = _user!.copyWith(biometricEnabled: enabled);
      if (!enabled) _isBiometricAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      setError(e.toString());
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (_user == null) {
      _user = await _authRepository.getCurrentUserModel();
    }

    final bioEnabled = await _storageService.read('biometric_enabled');
    if (bioEnabled != 'true') return false;

    // Incognito fix: localStorage is wiped when an Incognito session ends.
    // Restore the credential from Firestore into localStorage before prompting.
    if (kIsWeb && _user != null) {
      try {
        final cred = await _firestoreService.getWebAuthnCredential(_user!.uid);
        if (cred.credentialId != null && cred.credentialId!.isNotEmpty) {
          // loadCredentialId() is from local_auth_service_web.dart
          loadCredentialId(cred.credentialId!, cred.rpId ?? '');
        } else {
          debugPrint('[AuthVM] No WebAuthn credential in Firestore.');
          return false;
        }
      } catch (e) {
        debugPrint('[AuthVM] Failed to load credential from Firestore: $e');
      }
    }

    bool success = await _localAuthService.authenticate();
    if (success) {
      _isBiometricAuthenticated = true;
      _biometricFailCount = 0;
    } else {
      _biometricFailCount++;
      if (_biometricFailCount >= 3) {
        setError("Too many failed attempts. Please use your password.",
            seconds: 999);
      }
    }
    notifyListeners();
    return success;
  }

  Future<bool> setSecurePin(String pin) async {
    if (_user == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateSecurePin(_user!.uid, pin);
      _user = _user!.copyWith(securePin: pin);
      _isPinAuthenticated = true;
      _isBiometricAuthenticated = true;
      setSuccess("Secure PIN set successfully!");
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      setError("Failed to set PIN: ${e.toString()}");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeSecurePin() async {
    if (_user == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateSecurePin(_user!.uid, null);
      _user = _user!.copyWith(clearPin: true);
      setSuccess("Secure PIN disabled.");
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      setError("Failed to remove PIN: ${e.toString()}");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPin(String enteredPin) async {
    if (_user == null || _user!.securePin == null) return false;
    if (_user!.securePin == enteredPin) {
      _isPinAuthenticated = true;
      _isBiometricAuthenticated = true;
      _biometricFailCount = 0;
      setSuccess("App unlocked successfully!");
      notifyListeners();
      return true;
    } else {
      _biometricFailCount++;
      setError("Incorrect PIN. Attempt $_biometricFailCount/3.");
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPassword(String password) async {
    if (_user == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _authRepository.login(_user!.email, password);
      if (result != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
      }
      _isLoading = false;
      notifyListeners();
      return result != null;
    } catch (e) {
      setError("Invalid password. Please try again.");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void resetBiometricAuth() {
    _isBiometricAuthenticated = false;
    _isPinAuthenticated = false;
    _biometricFailCount = 0;
    notifyListeners();
  }

  void resetBiometricLockout() {
    _biometricFailCount = 0;
    notifyListeners();
  }
}