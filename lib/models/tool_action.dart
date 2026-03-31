class ToolAction {
  const ToolAction({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isPremium = false,
  });

  final String id;
  final String title;
  final String description;
  final int icon;
  final bool isPremium;
}
