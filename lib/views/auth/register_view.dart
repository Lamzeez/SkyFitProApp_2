import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_widgets.dart';
import '../home_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Register"), backgroundColor: Colors.lightBlue),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: _fullNameController,
                label: "Full Name",
                validator: (v) => v!.isEmpty ? "Enter full name" : null,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _ageController,
                label: "Age",
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter age" : null,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _weightController,
                label: "Weight (kg)",
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter weight" : null,
              ),
              const SizedBox(height: 20),
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
                text: "Register",
                isLoading: authViewModel.isLoading,
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    bool success = await authViewModel.register(
                      _emailController.text,
                      _passwordController.text,
                      _fullNameController.text,
                      int.parse(_ageController.text),
                      double.parse(_weightController.text),
                    );
                    if (success && mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeView()),
                        (route) => false,
                      );
                    }
                  }
                },
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
    );
  }
}
