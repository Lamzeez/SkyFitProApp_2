import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/env_config.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfileImage(String uid, Uint8List fileData) async {
    if (!EnvConfig.isFirebaseConfigured) return null;

    try {
      final ref = _storage.ref().child('user_profiles').child('$uid.jpg');
      
      // Adding a timeout to prevent the app from hanging indefinitely on Web
      final uploadTask = ref.putData(
        fileData,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Wait for the upload with a 15-second timeout
      final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image (likely CORS or timeout): $e");
      // Rethrowing to allow AuthRepository to catch and display the error
      rethrow;
    }
  }
}
