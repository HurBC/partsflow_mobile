class QuickAnswer {
  const QuickAnswer({
    required this.id,
    required this.title,
    this.message,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? message;
  final String? imageUrl;
}
