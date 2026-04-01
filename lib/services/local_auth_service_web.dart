// local_auth_service_web.dart — compiled ONLY on web builds.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

@JS('PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable')
external JSPromise<JSBoolean> _isUVPAAvailable();

// ── Public API ────────────────────────────────────────────────────────────────

Future<bool> webAuthnIsAvailable() async {
  try {
    final hasApi = web.window.getProperty<JSAny?>('PublicKeyCredential'.toJS);
    if (hasApi == null) {
      debugPrint('[WebAuthn] API not available in this browser.');
      return false;
    }
    try {
      final uvpa = await _isUVPAAvailable().toDart;
      debugPrint('[WebAuthn] Platform authenticator enrolled: ${uvpa.toDart}');
    } catch (e) {
      debugPrint('[WebAuthn] UVPA check skipped: $e');
    }
    // Return true as long as the API exists — let the browser reject at
    // prompt time if no hardware is enrolled, rather than blocking here.
    return true;
  } catch (e) {
    debugPrint('[WebAuthn] Availability check failed: $e');
    return false;
  }
}

Future<bool> webAuthnRegister(String userId, String userName) async {
  try {
    _ensureHelperScript();
    final hostname = web.window.location.hostname;
    debugPrint('[WebAuthn] Registering for rpId: $hostname');

    final args = jsonEncode({
      'challenge': _randomB64(),
      'rpId': hostname,
      'rpName': 'SkyFit Pro',
      'userId': base64Url.encode(utf8.encode(userId)),
      'userName': userName,
      'displayName': userName,
    });

    final fn = web.window.getProperty<JSFunction?>('skyfit_webauthn_register'.toJS);
    if (fn == null) {
      debugPrint('[WebAuthn] register fn not found.');
      return false;
    }

    final promise = fn.callAsFunction(null, args.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;

    if (result == null) {
      debugPrint('[WebAuthn] Register returned null — cancelled or no hardware.');
      return false;
    }

    final credentialId = (result as JSString).toDart;
    if (credentialId.isEmpty) return false;

    // Cache in localStorage for fast same-session use
    web.window.localStorage.setItem('skyfit_webauthn_id', credentialId);
    web.window.localStorage.setItem('skyfit_webauthn_rpid', hostname);
    // Expose for auth_viewmodel to pick up and save to Firestore
    web.window.localStorage.setItem('skyfit_webauthn_pending_id', credentialId);

    debugPrint('[WebAuthn] Credential registered: $credentialId');
    return true;
  } catch (e) {
    debugPrint('[WebAuthn] Registration failed: $e');
    return false;
  }
}

Future<bool> webAuthnAuthenticate() async {
  try {
    final storedId = web.window.localStorage.getItem('skyfit_webauthn_id');
    final storedRpId = web.window.localStorage.getItem('skyfit_webauthn_rpid')
        ?? web.window.location.hostname;

    if (storedId == null || storedId.isEmpty) {
      debugPrint('[WebAuthn] No credential in localStorage.');
      return false;
    }

    debugPrint('[WebAuthn] Authenticating with rpId: $storedRpId');
    _ensureHelperScript();

    final args = jsonEncode({
      'challenge': _randomB64(),
      'rpId': storedRpId,
      'credentialId': storedId,
    });

    final fn = web.window.getProperty<JSFunction?>('skyfit_webauthn_authenticate'.toJS);
    if (fn == null) {
      debugPrint('[WebAuthn] authenticate fn not found.');
      return false;
    }

    final promise = fn.callAsFunction(null, args.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;

    if (result == null) return false;
    final success = (result as JSBoolean).toDart;
    debugPrint('[WebAuthn] Authentication result: $success');
    return success;
  } catch (e) {
    debugPrint('[WebAuthn] Authentication failed: $e');
    return false;
  }
}

/// Returns the credential ID that was just registered.
/// auth_viewmodel calls this immediately after webAuthnRegister() returns true
/// to get the value it needs to save to Firestore.
String? getLastRegisteredCredentialId() {
  return web.window.localStorage.getItem('skyfit_webauthn_pending_id');
}

/// Returns the rpId that was used at registration time.
String getStoredRpId() {
  return web.window.localStorage.getItem('skyfit_webauthn_rpid')
      ?? web.window.location.hostname;
}

/// Loads [credentialId] and [rpId] from Firestore (supplied by auth_viewmodel)
/// into localStorage so webAuthnAuthenticate() can find them.
/// Called before every authentication attempt when on web.
void loadCredentialId(String credentialId, String rpId) {
  web.window.localStorage.setItem('skyfit_webauthn_id', credentialId);
  if (rpId.isNotEmpty) {
    web.window.localStorage.setItem('skyfit_webauthn_rpid', rpId);
  }
  debugPrint('[WebAuthn] Credential loaded from Firestore into localStorage.');
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _randomB64() {
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  return base64Url.encode(bytes);
}

bool _helperInjected = false;

void _ensureHelperScript() {
  if (_helperInjected) return;
  _helperInjected = true;

  const src = r"""
(function () {
  function b64ToBuffer(b64) {
    const padded = b64.replace(/-/g, '+').replace(/_/g, '/');
    const bin = atob(padded);
    const buf = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
    return buf.buffer;
  }
  function bufferToB64(buffer) {
    const bytes = new Uint8Array(buffer);
    let bin = '';
    bytes.forEach(function (b) { bin += String.fromCharCode(b); });
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  }

  window.skyfit_webauthn_register = async function (jsonArgs) {
    try {
      const o = JSON.parse(jsonArgs);
      const credential = await navigator.credentials.create({
        publicKey: {
          challenge: b64ToBuffer(o.challenge),
          rp: { id: o.rpId, name: o.rpName },
          user: {
            id: b64ToBuffer(o.userId),
            name: o.userName,
            displayName: o.displayName,
          },
          pubKeyCredParams: [
            { alg: -7,   type: 'public-key' },
            { alg: -257, type: 'public-key' },
          ],
          authenticatorSelection: {
            authenticatorAttachment: 'platform',
            userVerification: 'required',
          },
          timeout: 60000,
          attestation: 'none',
        },
      });
      return credential ? bufferToB64(credential.rawId) : null;
    } catch (err) {
      console.warn('[SkyFit WebAuthn] Register error:', err.name, '-', err.message);
      return null;
    }
  };

  window.skyfit_webauthn_authenticate = async function (jsonArgs) {
    try {
      const o = JSON.parse(jsonArgs);
      const assertion = await navigator.credentials.get({
        publicKey: {
          rpId: o.rpId,
          challenge: b64ToBuffer(o.challenge),
          allowCredentials: [{
            id: b64ToBuffer(o.credentialId),
            type: 'public-key',
            transports: ['internal'],
          }],
          userVerification: 'required',
          timeout: 60000,
        },
      });
      return assertion !== null;
    } catch (err) {
      console.warn('[SkyFit WebAuthn] Authenticate error:', err.name, '-', err.message);
      return false;
    }
  };
})();
""";

  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.textContent = src;
  web.document.head!.appendChild(script);
}