// ============================================================
// YATIRIM MODELİ
// ============================================================

class Investment {
  final int? id;
  final String type;
  final double quantity;
  final double purchasePrice;
  final double currentPrice;
  final String date;

  const Investment({
    this.id,
    required this.type,
    required this.quantity,
    required this.purchasePrice,
    required this.currentPrice,
    required this.date,
  });

  double get totalCost => quantity * purchasePrice;
  double get currentValue => quantity * currentPrice;
  double get profitLoss => currentValue - totalCost;
  double get profitLossPercent =>
      totalCost == 0 ? 0 : (profitLoss / totalCost) * 100;

  Investment copyWith({double? currentPrice}) {
    return Investment(
      id: id,
      type: type,
      quantity: quantity,
      purchasePrice: purchasePrice,
      currentPrice: currentPrice ?? this.currentPrice,
      date: date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'currentPrice': currentPrice,
      'date': date,
    };
  }

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'] as int?,
      type: map['type'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      purchasePrice: (map['purchasePrice'] as num).toDouble(),
      currentPrice: (map['currentPrice'] as num).toDouble(),
      date: map['date'] as String,
    );
  }
}
