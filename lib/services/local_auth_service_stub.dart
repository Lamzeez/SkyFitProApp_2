// Stub implementation for non-web platforms (Android, iOS, desktop).
// These functions are never actually called on mobile — LocalAuthService
// checks `kIsWeb` first and routes to local_auth instead. This file only
// exists so the Dart compiler is satisfied that the symbols exist on all
// platforms during the conditional import resolution.

Future<bool> webAuthnIsAvailable() async => false;

Future<bool> webAuthnRegister(String userId, String userName) async => false;

Future<bool> webAuthnAuthenticate() async => false;
