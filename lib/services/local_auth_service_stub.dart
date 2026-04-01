// Stub for non-web platforms.
// Must declare every top-level function that local_auth_service_web.dart exports
// so the Dart compiler is satisfied on all platforms.

Future<bool> webAuthnIsAvailable() async => false;
Future<bool> webAuthnRegister(String userId, String userName) async => false;
Future<bool> webAuthnAuthenticate() async => false;
String? getLastRegisteredCredentialId() => null;
String getStoredRpId() => '';
void loadCredentialId(String credentialId, String rpId) {}