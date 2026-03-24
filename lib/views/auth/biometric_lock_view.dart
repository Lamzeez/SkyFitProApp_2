import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_widgets.dart';

class BiometricLockView extends StatelessWidget {
  const BiometricLockView({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                authViewModel.biometricLockedOut ? Icons.lock : Icons.fingerprint,
                size: 100,
                color: Colors.lightBlue,
              ),
              const SizedBox(height: 20),
              Text(
                authViewModel.biometricLockedOut 
                  ? "Too many failed attempts" 
                  : "Welcome back, ${authViewModel.user?.fullName ?? ''}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                authViewModel.biometricLockedOut 
                  ? "Please log in with your password to continue." 
                  : "Please authenticate to access your health data.",
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 40),
              if (!authViewModel.biometricLockedOut)
                CustomButton(
                  text: "Authenticate",
                  onPressed: () async {
                    await authViewModel.authenticateWithBiometrics();
                  },
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  await authViewModel.logout();
                },
                child: const Text("Switch Account / Use Password"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
