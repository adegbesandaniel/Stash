class TransactionModel {
  final String type;
  final String category;
  final double amount;
  final String note;
  final DateTime date;

  TransactionModel({
    required this.type,
    required this.category,
    required this.amount,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'category': category,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      type: map['type'],
      category: map['category'],
      amount: map['amount'].toDouble(),
      note: map['note'],
      date: DateTime.parse(map['date']),
    );
  }
}
