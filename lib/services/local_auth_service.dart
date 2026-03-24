import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class LocalAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      print("Error checking biometrics: $e");
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (kIsWeb) {
      // For the sake of the lab exercise on web, we can simulate success if needed,
      // but strictly speaking, it's not supported.
      print("Biometrics not supported on Web. Returning true for simulation.");
      return true; 
    }
    
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access your health data',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print("Error authenticating: $e");
      return false;
    }
  }
}
