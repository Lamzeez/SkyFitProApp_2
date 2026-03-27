class ActivityModel {
  final String title;
  final String description;
  final String? mediaUrl; // Can be a local asset or network URL (AI Generated)

  ActivityModel({
    required this.title,
    required this.description,
    this.mediaUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'mediaUrl': mediaUrl,
    };
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      mediaUrl: map['mediaUrl'],
    );
  }
}
