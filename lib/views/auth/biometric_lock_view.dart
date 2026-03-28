import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-switch to PIN if biometrics fail or aren't the primary choice but PIN is set
    bool showPinEntry = _usePin || (authViewModel.pinEnabled && !authViewModel.isBiometricAuthenticated && authViewModel.biometricLockedOut);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  authViewModel.biometricLockedOut ? Icons.lock_outline : (showPinEntry ? Icons.dialpad : Icons.fingerprint),
                  size: 100,
                  color: Colors.lightBlue,
                ),
                const SizedBox(height: 20),
                Text(
                  authViewModel.biometricLockedOut 
                    ? "Security Lock" 
                    : "Welcome back, ${authViewModel.user?.fullName ?? ''}",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _getSubtitleText(authViewModel),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 40),
                
                if (authViewModel.biometricLockedOut) ...[
                  CustomTextField(
                    controller: _passwordController,
                    label: "Account Password",
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
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(authViewModel.error ?? "Authentication failed")),
                          );
                        }
                      }
                    },
                  ),
                ] else if (showPinEntry) ...[
                  CustomTextField(
                    controller: _pinController,
                    label: "Enter 4-6 Digit PIN",
                    isPassword: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) => v!.length < 4 ? "Enter valid PIN" : null,
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: "Verify PIN",
                    isLoading: authViewModel.isLoading,
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await authViewModel.verifyPin(_pinController.text);
                      }
                    },
                  ),
                  if (authViewModel.user?.biometricEnabled == true)
                    TextButton(
                      onPressed: () => setState(() => _usePin = false),
                      child: const Text("Use Biometrics instead"),
                    ),
                ] else ...[
                  CustomButton(
                    text: "Authenticate with Biometrics",
                    onPressed: () async {
                      bool success = await authViewModel.authenticateWithBiometrics();
                      if (!success && authViewModel.pinEnabled) {
                        setState(() => _usePin = true);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (authViewModel.pinEnabled)
                    TextButton(
                      onPressed: () => setState(() => _usePin = true),
                      child: const Text("Use Secure PIN"),
                    ),
                  TextButton(
                    onPressed: () {
                      authViewModel.logout(); 
                    },
                    child: const Text("Sign Out / Switch Account"),
                  ),
                ],
                
                if (authViewModel.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(authViewModel.error!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSubtitleText(AuthViewModel vm) {
    if (vm.biometricLockedOut) {
      return "Too many failed attempts. Please enter your account password to unlock.";
    }
    if (_usePin || (vm.pinEnabled && !vm.isBiometricAuthenticated)) {
      return "Please enter your Secure PIN to continue.";
    }
    return "Please authenticate to access your health data.";
  }
}
