import 'package:flutter/material.dart';
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
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  authViewModel.biometricLockedOut ? Icons.lock_outline : Icons.fingerprint,
                  size: 100,
                  color: Colors.lightBlue,
                ),
                const SizedBox(height: 20),
                Text(
                  authViewModel.biometricLockedOut 
                    ? "Biometrics Locked" 
                    : "Welcome back, ${authViewModel.user?.fullName ?? ''}",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  authViewModel.biometricLockedOut 
                    ? "Too many failed attempts. Please enter your password to unlock." 
                    : "Please authenticate to access your health data.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 40),
                
                if (authViewModel.biometricLockedOut) ...[
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
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(authViewModel.error ?? "Authentication failed")),
                          );
                        }
                      }
                    },
                  ),
                ] else ...[
                  CustomButton(
                    text: "Authenticate with Biometrics",
                    onPressed: () async {
                      await authViewModel.authenticateWithBiometrics();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      // Manual fallback if biometrics are acting up but not locked yet
                      // We can force show the password field or just let them logout
                      // For now, let's allow them to switch to password mode manually
                      authViewModel.logout(); 
                    },
                    child: const Text("Use Password / Switch Account"),
                  ),
                ],
                
                if (authViewModel.error != null && authViewModel.biometricLockedOut)
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
}
