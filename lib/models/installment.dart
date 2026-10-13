// ============================================================
// TAKSİT MODELİ
// ============================================================

class Installment {
  final int? id;
  final String title;
  final String category;
  final double totalAmount;
  final int totalMonths;
  final int paidMonths;
  final String startDate;

  const Installment({
    this.id,
    required this.title,
    required this.category,
    required this.totalAmount,
    required this.totalMonths,
    required this.paidMonths,
    required this.startDate,
  });

  double get monthlyAmount => totalMonths == 0 ? 0 : totalAmount / totalMonths;

  double get remainingAmount {
    final r = totalAmount - (monthlyAmount * paidMonths);
    return r < 0 ? 0 : r;
  }

  int get remainingMonths => totalMonths - paidMonths;

  bool get isCompleted => paidMonths >= totalMonths;

  double get progress {
    if (totalMonths == 0) return 0;
    final p = paidMonths / totalMonths;
    return p.clamp(0, 1);
  }

  Installment copyWith({int? paidMonths}) {
    return Installment(
      id: id,
      title: title,
      category: category,
      totalAmount: totalAmount,
      totalMonths: totalMonths,
      paidMonths: paidMonths ?? this.paidMonths,
      startDate: startDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'totalAmount': totalAmount,
      'totalMonths': totalMonths,
      'paidMonths': paidMonths,
      'startDate': startDate,
    };
  }

  factory Installment.fromMap(Map<String, dynamic> map) {
    return Installment(
      id: map['id'] as int?,
      title: map['title'] as String,
      category: map['category'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      totalMonths: map['totalMonths'] as int,
      paidMonths: map['paidMonths'] as int,
      startDate: map['startDate'] as String,
    );
  }
}
