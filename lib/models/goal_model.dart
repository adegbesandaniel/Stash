class GoalModel {
  final String id;
  final String title;
  final String icon; // emoji
  final double target;
  final double saved;
  final String? targetDate; // ISO-8601 string, optional
  final String createdAt; // ISO-8601 string

  GoalModel({
    required this.id,
    required this.title,
    required this.icon,
    required this.target,
    required this.saved,
    this.targetDate,
    required this.createdAt,
  });

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  double get remaining => (target - saved) <= 0 ? 0 : (target - saved);
  bool get isComplete => target > 0 && saved >= target;

  /// Safely coerce a Firestore value (num, String, or null) to a double.
  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  factory GoalModel.fromDoc(String id, Map<String, dynamic> map) {
    final rawIcon = map['icon'] as String?;
    return GoalModel(
      id: id,
      title: (map['title'] as String?) ?? '',
      icon: (rawIcon != null && rawIcon.isNotEmpty) ? rawIcon : '🎯',
      target: _toDouble(map['target']),
      saved: _toDouble(map['saved']),
      targetDate: map['targetDate'] as String?,
      createdAt: (map['createdAt'] as String?) ?? '',
    );
  }
}
