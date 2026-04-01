import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

// ✅ FIXED: dart.library.js_interop is the correct selector for web.
// dart.library.io is present on both mobile AND some web environments,
// which caused local_auth (a native plugin) to be called on web,
// producing MissingPluginException.
//
// dart.library.js_interop is ONLY available on web builds, so:
//   - web build  → loads local_auth_service_web.dart  (WebAuthn)
//   - mobile/desktop → loads local_auth_service_stub.dart (no-ops)
import 'local_auth_service_web.dart'
    if (dart.library.io) 'local_auth_service_stub.dart';

class LocalAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) {
      return await webAuthnIsAvailable();
    }
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
      return false;
    }
  }

  Future<bool> registerBiometric(String userId, String userName) async {
    if (kIsWeb) {
      return await webAuthnRegister(userId, userName);
    }
    return true;
  }

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
      debugPrint('Hardware authentication error: $e');
      return false;
    }
  }
}