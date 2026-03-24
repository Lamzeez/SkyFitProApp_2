class ActivityModel {
  final String title;
  final String description;
  final String? mediaUrl; // Can be a local asset or network URL (AI Generated)

  ActivityModel({
    required this.title,
    required this.description,
    this.mediaUrl,
  });
}
