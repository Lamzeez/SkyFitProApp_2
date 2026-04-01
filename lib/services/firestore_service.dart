import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/env_config.dart';

class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> createUser(UserModel user) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    if (!EnvConfig.isFirebaseConfigured) {
      return UserModel(
        uid: uid,
        email: "test@example.com",
        fullName: "Mock User",
        age: 25,
        weight: 70.0,
        height: 170.0,
      );
    }
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, uid);
    }
    return null;
  }

  Future<void> updateUser(UserModel user) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(user.uid).update(user.toMap());
  }

  Future<void> updateBiometricStatus(String uid, bool isEnabled) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db
        .collection('users')
        .doc(uid)
        .update({'biometricEnabled': isEnabled});
  }

  Future<void> updateSecurePin(String uid, String? pin) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(uid).update({'securePin': pin});
  }

  Future<bool> isEmailTaken(String email) async {
    if (!EnvConfig.isFirebaseConfigured) return false;
    final query = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<void> deleteUser(String uid) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(uid).delete();
  }

  // ── WebAuthn credential storage ───────────────────────────────────────────
  // The WebAuthn credential ID is a device-bound token produced by the
  // browser during registration. We store it in Firestore so it survives
  // Incognito sessions (where localStorage is wiped on session end).
  //
  // Firestore field: users/{uid}.webAuthnCredentialId  (String | null)
  // Firestore field: users/{uid}.webAuthnRpId          (String | null)

  /// Saves the WebAuthn credential ID and the rpId it was registered for.
  /// Called once when the user enables biometric login.
  Future<void> saveWebAuthnCredentialId(
      String uid, String credentialId, String rpId) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(uid).update({
      'webAuthnCredentialId': credentialId,
      'webAuthnRpId': rpId,
    });
  }

  /// Fetches the stored WebAuthn credential ID and rpId for [uid].
  /// Returns null values if none are stored yet.
  Future<({String? credentialId, String? rpId})> getWebAuthnCredential(
      String uid) async {
    if (!EnvConfig.isFirebaseConfigured) {
      return (credentialId: null, rpId: null);
    }
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      return (
        credentialId: data?['webAuthnCredentialId'] as String?,
        rpId: data?['webAuthnRpId'] as String?,
      );
    } catch (e) {
      return (credentialId: null, rpId: null);
    }
  }

  /// Clears the stored WebAuthn credential when biometrics are disabled.
  Future<void> clearWebAuthnCredential(String uid) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(uid).update({
      'webAuthnCredentialId': null,
      'webAuthnRpId': null,
    });
  }
}