import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

// Conditional import: on web, load the real WebAuthn helper;
// on mobile/desktop (dart:io is available), load the no-op stub.
import 'local_auth_service_web.dart' if (dart.library.io) 'local_auth_service_stub.dart';

/// Unified biometric service.
///
/// On web    → delegates to WebAuthn via JS interop (browser fingerprint / FaceID).
/// On mobile → delegates to the [LocalAuthentication] package.
class LocalAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  // ── Availability ──────────────────────────────────────────────────────────

  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) {
      return await webAuthnIsAvailable();
    }
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint("Error checking biometrics: $e");
      return false;
    }
  }

  // ── Registration (web only) ───────────────────────────────────────────────

  /// Creates a WebAuthn credential tied to [userId] / [userName].
  /// Called once when the user first enables biometrics in ProfileView.
  /// On mobile this is a no-op — local_auth handles everything in authenticate().
  Future<bool> registerBiometric(String userId, String userName) async {
    if (kIsWeb) {
      return await webAuthnRegister(userId, userName);
    }
    return true;
  }

  // ── Authentication ────────────────────────────────────────────────────────

  Future<bool> authenticate() async {
    if (kIsWeb) {
      return await webAuthnAuthenticate();
    }
    try {
      return await _auth.authenticate(
        localizedReason: 'Verify your identity to unlock SkyFit Pro',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint("Hardware authentication error: $e");
      return false;
    }
  }
}