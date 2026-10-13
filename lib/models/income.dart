// ============================================================
// GELİR MODELİ
// ============================================================

class Income {
  final int? id;
  final String source;
  final String description;
  final double amount;
  final String date;
  final bool isRecurring;

  const Income({
    this.id,
    required this.source,
    required this.description,
    required this.amount,
    required this.date,
    required this.isRecurring,
  });

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'description': description,
      'amount': amount,
      'date': date,
      'isRecurring': isRecurring ? 1 : 0,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'] as int?,
      source: map['source'] as String,
      description: (map['description'] ?? '') as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      isRecurring: (map['isRecurring'] as int) == 1,
    );
  }
}
