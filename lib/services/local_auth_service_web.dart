// local_auth_service_web.dart — compiled ONLY on web builds.
// Uses dart:js_interop + dart:js_interop_unsafe + package:web (all non-deprecated).

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

// ── JS interop: PublicKeyCredential static method ─────────────────────────────

@JS('PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable')
external JSPromise<JSBoolean> _isUVPAAvailable();

// ── Public API ────────────────────────────────────────────────────────────────

Future<bool> webAuthnIsAvailable() async {
  try {
    // 1. Does the browser expose the WebAuthn API at all?
    final hasApi = web.window.getProperty<JSAny?>('PublicKeyCredential'.toJS);
    if (hasApi == null) {
      debugPrint('[WebAuthn] PublicKeyCredential API not found in this browser.');
      return false;
    }

    // 2. Is a platform authenticator (biometric hardware) enrolled?
    //    This returns false on devices with no fingerprint/FaceID/Windows Hello set up.
    //    It also returns false if called from an insecure (HTTP) origin.
    try {
      final result = await _isUVPAAvailable().toDart;
      final enrolled = result.toDart;
      debugPrint('[WebAuthn] Platform authenticator available: $enrolled');

      // 3. If no biometric is enrolled, fall back to checking whether
      //    the browser supports WebAuthn at all (conditional mediation).
      //    This allows users who only have a PIN/password device authenticator
      //    to still use the credential flow.
      if (!enrolled) {
        // Check if ConditionalMediationAvailable exists (Chrome 108+)
        final hasConditional = web.window.getProperty<JSAny?>(
          'PublicKeyCredential'.toJS,
        );
        // We already know the API exists — treat as available and let the
        // browser decide at registration time. This avoids false negatives
        // on devices where UVPA check is unreliable (some Android browsers).
        debugPrint(
          '[WebAuthn] No platform authenticator enrolled, but WebAuthn API exists. '
          'Allowing toggle — browser will show its own error if hardware is missing.',
        );
        return true;
      }

      return true;
    } catch (uvpaError) {
      // Some browsers throw if called in an insecure context
      debugPrint('[WebAuthn] UVPA check threw: $uvpaError');
      // If the API exists but UVPA throws, still allow — let the browser decide
      return true;
    }
  } catch (e) {
    debugPrint('[WebAuthn] Availability check failed: $e');
    return false;
  }
}

Future<bool> webAuthnRegister(String userId, String userName) async {
  try {
    _ensureHelperScript();

    // rpId MUST match the hostname of the page exactly.
    // window.location.hostname gives us "skyfit-pro-app.onrender.com" on Render,
    // or "localhost" locally — both work correctly this way.
    final hostname = web.window.location.hostname;
    debugPrint('[WebAuthn] Registering credential for rpId: $hostname');

    final args = jsonEncode({
      'challenge': _randomB64(),
      'rpId': hostname,
      'rpName': 'SkyFit Pro',
      'userId': base64Url.encode(utf8.encode(userId)),
      'userName': userName,
      'displayName': userName,
    });

    final fn = web.window
        .getProperty<JSFunction?>('skyfit_webauthn_register'.toJS);
    if (fn == null) {
      debugPrint('[WebAuthn] Helper script not loaded — register fn missing.');
      return false;
    }

    final promise = fn.callAsFunction(null, args.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;

    if (result == null) {
      debugPrint('[WebAuthn] Register returned null — user likely cancelled.');
      return false;
    }

    final credentialId = (result as JSString).toDart;
    if (credentialId.isEmpty) return false;

    // Store credential ID and the rpId it was created for
    web.window.localStorage.setItem('skyfit_webauthn_id', credentialId);
    web.window.localStorage.setItem('skyfit_webauthn_rpid', hostname);
    debugPrint('[WebAuthn] Credential registered successfully: $credentialId');
    return true;
  } catch (e) {
    debugPrint('[WebAuthn] Registration failed: $e');
    return false;
  }
}

Future<bool> webAuthnAuthenticate() async {
  try {
    final storedId =
        web.window.localStorage.getItem('skyfit_webauthn_id');
    if (storedId == null || storedId.isEmpty) {
      debugPrint('[WebAuthn] No stored credential — user must enable biometrics first.');
      return false;
    }

    // Use the rpId that was set at registration time
    final storedRpId =
        web.window.localStorage.getItem('skyfit_webauthn_rpid') ??
        web.window.location.hostname;

    debugPrint('[WebAuthn] Authenticating with rpId: $storedRpId');
    _ensureHelperScript();

    final args = jsonEncode({
      'challenge': _randomB64(),
      'rpId': storedRpId,
      'credentialId': storedId,
    });

    final fn = web.window
        .getProperty<JSFunction?>('skyfit_webauthn_authenticate'.toJS);
    if (fn == null) {
      debugPrint('[WebAuthn] Helper script not loaded — authenticate fn missing.');
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

// ── Helpers ───────────────────────────────────────────────────────────────────

String _randomB64() {
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  return base64Url.encode(bytes);
}

// ── JS helper script ──────────────────────────────────────────────────────────
// Injected once into <head>. Exposes two async functions on window that handle
// all ArrayBuffer ↔ base64url conversion and the WebAuthn API calls.
// rpId is passed in the JSON args so it matches the registration origin exactly.

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
          rp: {
            id: o.rpId,
            name: o.rpName,
          },
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
      console.warn('[SkyFit WebAuthn] Register error:', err.name, err.message);
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
      console.warn('[SkyFit WebAuthn] Authenticate error:', err.name, err.message);
      return false;
    }
  };
})();
""";

  final script =
      web.document.createElement('script') as web.HTMLScriptElement;
  script.textContent = src;
  web.document.head!.appendChild(script);
}