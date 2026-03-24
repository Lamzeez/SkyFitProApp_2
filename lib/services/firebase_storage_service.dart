import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/env_config.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfileImage(String uid, Uint8List fileData) async {
    if (!EnvConfig.isFirebaseConfigured) return null;

    try {
      final ref = _storage.ref().child('user_profiles').child('$uid.jpg');
      final uploadTask = ref.putData(
        fileData,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }
}
