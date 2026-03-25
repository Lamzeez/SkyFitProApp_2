import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/storage_service.dart';
import '../widgets/custom_widgets.dart';
import 'register_view.dart';
import '../home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _canUseBiometrics = false;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _checkBiometricPreference();
  }

  Future<void> _checkBiometricPreference() async {
    final enabled = await _storage.read('biometric_enabled');
    if (enabled == 'true') {
      setState(() => _canUseBiometrics = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_queue, size: 100, color: Colors.lightBlue),
                const SizedBox(height: 20),
                const Text(
                  "SkyFit Pro",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.lightBlue),
                ),
                const SizedBox(height: 40),
                CustomTextField(
                  controller: _emailController,
                  label: "Email",
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? "Enter email" : null,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _passwordController,
                  label: "Password",
                  isPassword: true,
                  validator: (v) => v!.length < 6 ? "Password too short" : null,
                ),
                const SizedBox(height: 30),
                CustomButton(
                  text: "Login",
                  isLoading: authViewModel.isLoading,
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      bool success = await authViewModel.login(
                        _emailController.text,
                        _passwordController.text,
                      );
                      if (success && mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeView()),
                        );
                      }
                    }
                  },
                ),
                if (_canUseBiometrics) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: authViewModel.isLoading ? null : () async {
                      bool success = await authViewModel.authenticateWithBiometrics();
                      if (success && mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeView()),
                        );
                      }
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text("Login with Biometrics"),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: authViewModel.isLoading ? null : () async {
                    bool success = await authViewModel.signInWithGoogle();
                    if (success && mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeView()),
                      );
                    }
                  },
                  icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.lightBlue),
                  label: Text(
                    "Sign in with Google",
                    style: TextStyle(color: isDark ? Colors.lightBlue[100] : Colors.lightBlue[800]),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Colors.lightBlue),
                    backgroundColor: isDark ? Colors.blueGrey[900] : Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterView()),
                    );
                  },
                  child: Text(
                    "Don't have an account? Register",
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
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
}
