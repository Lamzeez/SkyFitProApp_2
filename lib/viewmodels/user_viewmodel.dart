import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UserViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  Future<bool> updateProfile({String? fullName, int? age, double? weight}) async {
    if (_user == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = _user!.copyWith(
        fullName: fullName,
        age: age,
        weight: weight,
      );
      await _firestoreService.updateUser(updatedUser);
      _user = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
