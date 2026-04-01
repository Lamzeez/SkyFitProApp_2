import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_widgets.dart';
// ✅ ADDED: Need HomeView to navigate after successful unlock
import '../home_view.dart';

class BiometricLockView extends StatefulWidget {
  const BiometricLockView({super.key});

  @override
  State<BiometricLockView> createState() => _BiometricLockViewState();
}

class _BiometricLockViewState extends State<BiometricLockView> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _usePin = false;
  bool _usePassword = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = context.read<AuthViewModel>();
      // ✅ FIX: Added null-safety guard — user could be null on first load
      if (authVM.user != null && !authVM.user!.biometricEnabled && authVM.pinEnabled) {
        setState(() => _usePin = true);
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ✅ ADDED: Central success handler used by all three auth paths
  // (biometrics, PIN, password). Navigates to HomeView and resets lockout.
  void _onUnlockSuccess(AuthViewModel authVM) {
    if (!mounted) return;
    authVM.resetBiometricLockout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authViewModel.user;

    if (user == null) return const SizedBox.shrink();

    bool isLockedOut = authViewModel.biometricLockedOut || _usePassword;
    bool showPinEntry = !isLockedOut && _usePin;
    bool showBiometricButton = !isLockedOut && !showPinEntry && user.biometricEnabled;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branded Icon
                Icon(
                  isLockedOut ? Icons.lock_outline : (showPinEntry ? Icons.dialpad : Icons.fingerprint),
                  size: 80,
                  color: const Color(0xFF38B6FF),
                ),
                const SizedBox(height: 24),
                Text(
                  isLockedOut ? "Account Lock" : "Welcome back,",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // 1. PASSWORD FALLBACK
                if (isLockedOut) ...[
                  Text(
                    authViewModel.biometricLockedOut 
                      ? "Too many failed attempts. Enter password to unlock."
                      : "Enter your account password to continue.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _passwordController,
                    label: "Password",
                    isPassword: true,
                    validator: (v) => v!.isEmpty ? "Enter password" : null,
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: "Unlock with Password",
                    isLoading: authViewModel.isLoading,
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        bool success = await authViewModel.verifyPassword(_passwordController.text);
                        // ✅ ADDED: Navigate on success — previously missing
                        if (success) _onUnlockSuccess(authViewModel);
                      }
                    },
                  ),
                ] 
                
                // 2. PIN ENTRY
                else if (showPinEntry) ...[
                  const Text("Enter your Secure PIN"),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _pinController,
                    label: "PIN Code",
                    isPassword: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) => v!.length < 4 ? "Enter 4-6 digits" : null,
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: "Verify PIN",
                    isLoading: authViewModel.isLoading,
                    onPressed: () async {
                      bool success = await authViewModel.verifyPin(_pinController.text);
                      // ✅ ADDED: Navigate on success — previously missing
                      if (success) _onUnlockSuccess(authViewModel);
                    },
                  ),
                ]

                // 3. BIOMETRIC BUTTON
                else if (showBiometricButton) ...[
                  CustomButton(
                    text: "Authenticate with Biometrics",
                    onPressed: () async {
                      bool success = await authViewModel.authenticateWithBiometrics();
                      // ✅ ADDED: Navigate on success — previously missing.
                      // On failure × 3, biometricLockedOut becomes true and the
                      // widget rebuilds automatically into the password fallback.
                      if (success) _onUnlockSuccess(authViewModel);
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // --- FOOTER OPTIONS ---
                if (!isLockedOut) ...[
                  if (!_usePin && authViewModel.pinEnabled)
                    TextButton.icon(
                      onPressed: () => setState(() { _usePin = true; _usePassword = false; }),
                      icon: const Icon(Icons.dialpad, size: 16),
                      label: const Text("Sign in with PIN"),
                    ),
                  
                  if (_usePin && user.biometricEnabled)
                    TextButton.icon(
                      onPressed: () => setState(() { _usePin = false; _usePassword = false; }),
                      icon: const Icon(Icons.fingerprint, size: 16),
                      label: const Text("Use Biometrics instead"),
                    ),

                  TextButton.icon(
                    onPressed: () => setState(() { _usePassword = true; _usePin = false; }),
                    icon: const Icon(Icons.password, size: 16),
                    label: const Text("Sign in with password instead"),
                  ),
                ],

                TextButton(
                  onPressed: () => authViewModel.logout(),
                  child: Text(
                    "Sign Out / Switch Account",
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                  ),
                ),
                
                if (authViewModel.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(authViewModel.error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}