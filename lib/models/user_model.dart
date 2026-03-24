class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final int age;
  final double weight;
  final bool biometricEnabled;
  final String? profilePictureUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.age,
    required this.weight,
    this.biometricEnabled = false,
    this.profilePictureUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      age: map['age'] ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      biometricEnabled: map['biometricEnabled'] ?? false,
      profilePictureUrl: map['profilePictureUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'age': age,
      'weight': weight,
      'biometricEnabled': biometricEnabled,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  UserModel copyWith({
    String? fullName,
    int? age,
    double? weight,
    bool? biometricEnabled,
    String? profilePictureUrl,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    );
  }
}
