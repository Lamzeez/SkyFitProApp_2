import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/user_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import 'widgets/custom_widgets.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  bool _initialized = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final authViewModel = context.watch<AuthViewModel>();
      final user = authViewModel.user;
      if (user != null) {
        _fullNameController.text = user.fullName;
        _ageController.text = user.age.toString();
        _weightController.text = user.weight.toString();
        context.read<UserViewModel>().setUser(user);
        _initialized = true;
      }
    }
  }

  Future<void> _pickAndUploadImage(UserViewModel userViewModel) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final Uint8List fileData = await image.readAsBytes();
        final url = await userViewModel.uploadProfilePicture(fileData);
        if (url != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated")),
          );
          // Sync back to AuthViewModel for global consistency
          await context.read<AuthViewModel>().refreshUser();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: $e")),
        );
      }
    }
  }

  ImageProvider? _getProfileImage(String? url) {
    if (url == null) return null;
    if (url.startsWith('data:image')) {
      final base64String = url.split(',').last;
      return MemoryImage(base64Decode(base64String));
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final userViewModel = context.watch<UserViewModel>();
    final themeViewModel = context.watch<ThemeViewModel>();
    final user = userViewModel.user ?? authViewModel.user;

    if (user == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    return Scaffold(
      appBar: AppBar(title: const Text("Profile"), backgroundColor: Theme.of(context).appBarTheme.backgroundColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _pickAndUploadImage(userViewModel),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.lightBlue,
                    backgroundImage: _getProfileImage(user.profilePictureUrl),
                    child: user.profilePictureUrl == null 
                      ? const Icon(Icons.person, size: 50, color: Colors.white) 
                      : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.lightBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(user.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            CustomTextField(controller: _fullNameController, label: "Full Name"),
            const SizedBox(height: 20),
            CustomTextField(controller: _ageController, label: "Age", keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            CustomTextField(controller: _weightController, label: "Weight (kg)", keyboardType: TextInputType.number),
            const SizedBox(height: 30),
            CustomButton(
              text: "Update Profile",
              isLoading: userViewModel.isLoading,
              onPressed: () async {
                bool success = await userViewModel.updateProfile(
                  fullName: _fullNameController.text,
                  age: int.tryParse(_ageController.text) ?? 0,
                  weight: double.tryParse(_weightController.text) ?? 0.0,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profile updated successfully")),
                  );
                  // Sync back to AuthViewModel
                  await context.read<AuthViewModel>().refreshUser();
                }
              },
            ),
            const SizedBox(height: 40),
            const Divider(),
            SwitchListTile(
              title: const Text("Dark Mode"),
              subtitle: const Text("Toggle between light and dark themes"),
              value: themeViewModel.isDarkMode,
              onChanged: (val) => themeViewModel.toggleTheme(),
            ),
            SwitchListTile(
              title: const Text("Enable Biometric Login"),
              subtitle: const Text("Use Fingerprint/FaceID to unlock"),
              value: user.biometricEnabled,
              onChanged: (val) async {
                bool success = await authViewModel.toggleBiometrics(val);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to toggle biometrics")),
                  );
                } else {
                  // Sync to userViewModel
                  userViewModel.setUser(authViewModel.user);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
