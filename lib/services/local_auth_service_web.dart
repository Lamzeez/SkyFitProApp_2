// ─────────────────────────────────────────────────────────────────────────────
// local_auth_service_web.dart
// Only compiled on web (conditional import in local_auth_service.dart).
//
// Strategy: inject a plain <script> into the page that puts two async
// functions on window (skyfit_webauthn_register / skyfit_webauthn_authenticate).
// Then call them from Dart using dart:js_interop + dart:js_interop_unsafe,
// which are the current non-deprecated APIs.
//
// Required in pubspec.yaml:
//   dependencies:
//     web: ^0.5.1   (or latest — already required by Flutter Web itself)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Interop: PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable
// ─────────────────────────────────────────────────────────────────────────────

@JS('PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable')
external JSPromise<JSBoolean> _isUVPAAvailable();

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> webAuthnIsAvailable() async {
  try {
    // Does the browser know WebAuthn at all?
    final hasApi = web.window.getProperty<JSAny?>('PublicKeyCredential'.toJS);
    if (hasApi == null) return false;

    // Does the device have enrolled biometrics (Touch ID, Windows Hello, etc.)?
    final result = await _isUVPAAvailable().toDart;
    return result.toDart;
  } catch (e) {
    debugPrint('WebAuthn availability check failed: $e');
    return false;
  }
}

Future<bool> webAuthnRegister(String userId, String userName) async {
  try {
    _ensureHelperScript();

    final args = jsonEncode({
      'challenge': _randomB64(),
      'rpName': 'SkyFit Pro',
      'userId': base64Url.encode(utf8.encode(userId)),
      'userName': userName,
      'displayName': userName,
    });

    final fn = web.window.getProperty<JSFunction?>('skyfit_webauthn_register'.toJS);
    if (fn == null) {
      debugPrint('WebAuthn helper script not loaded.');
      return false;
    }

    final promise = fn.callAsFunction(null, args.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;

    if (result == null) return false;
    final credentialId = (result as JSString).toDart;
    if (credentialId.isEmpty) return false;

    web.window.localStorage.setItem('skyfit_webauthn_id', credentialId);
    debugPrint('WebAuthn credential registered: $credentialId');
    return true;
  } catch (e) {
    debugPrint('WebAuthn registration failed: $e');
    return false;
  }
}

Future<bool> webAuthnAuthenticate() async {
  try {
    final storedId = web.window.localStorage.getItem('skyfit_webauthn_id');
    if (storedId == null || storedId.isEmpty) {
      debugPrint('No WebAuthn credential — user must enable biometrics first.');
      return false;
    }

    _ensureHelperScript();

    final args = jsonEncode({
      'challenge': _randomB64(),
      'credentialId': storedId,
    });

    final fn = web.window.getProperty<JSFunction?>('skyfit_webauthn_authenticate'.toJS);
    if (fn == null) {
      debugPrint('WebAuthn helper script not loaded.');
      return false;
    }

    final promise = fn.callAsFunction(null, args.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;

    if (result == null) return false;
    return (result as JSBoolean).toDart;
  } catch (e) {
    debugPrint('WebAuthn authentication failed or cancelled: $e');
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _randomB64() {
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  return base64Url.encode(bytes);
}

// ─────────────────────────────────────────────────────────────────────────────
// JS helper script — injected once into <head>
//
// Exposes two async functions on window:
//   skyfit_webauthn_register(jsonArgs)   → Promise<string | null>
//   skyfit_webauthn_authenticate(jsonArgs) → Promise<boolean>
// ─────────────────────────────────────────────────────────────────────────────

bool _helperInjected = false;

void _ensureHelperScript() {
  if (_helperInjected) return;
  _helperInjected = true;

  const src = r"""
(function () {
  // Convert a base64url string to an ArrayBuffer
  function b64ToBuffer(b64) {
    const padded = b64.replace(/-/g, '+').replace(/_/g, '/');
    const bin = atob(padded);
    const buf = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
    return buf.buffer;
  }

  // Convert an ArrayBuffer to a base64url string
  function bufferToB64(buffer) {
    const bytes = new Uint8Array(buffer);
    let bin = '';
    bytes.forEach(function (b) { bin += String.fromCharCode(b); });
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  }

  // Register a new WebAuthn credential
  window.skyfit_webauthn_register = async function (jsonArgs) {
    try {
      const o = JSON.parse(jsonArgs);
      const credential = await navigator.credentials.create({
        publicKey: {
          challenge: b64ToBuffer(o.challenge),
          rp: { name: o.rpName },
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
      console.warn('SkyFit WebAuthn register error:', err);
      return null;
    }
  };

  // Verify an existing WebAuthn credential
  window.skyfit_webauthn_authenticate = async function (jsonArgs) {
    try {
      const o = JSON.parse(jsonArgs);
      const assertion = await navigator.credentials.get({
        publicKey: {
          challenge: b64ToBuffer(o.challenge),
          allowCredentials: [
            {
              id: b64ToBuffer(o.credentialId),
              type: 'public-key',
              transports: ['internal'],
            },
          ],
          userVerification: 'required',
          timeout: 60000,
        },
      });
      return assertion !== null;
    } catch (err) {
      console.warn('SkyFit WebAuthn authenticate error:', err);
      return false;
    }
  };
})();
""";

  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.textContent = src;
  web.document.head!.appendChild(script);
}