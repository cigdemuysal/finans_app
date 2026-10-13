import 'package:flutter/material.dart';

// ============================================================
// HARCAMA MODELİ
// ============================================================

class Expense {
  final int? id;
  final String category;
  final String description;
  final double amount;
  final String date;
  final IconData icon;

  const Expense({
    this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'date': date,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      category: map['category'] as String,
      description: (map['description'] ?? '') as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      icon: iconForCategory(map['category'] as String),
    );
  }

  static IconData iconForCategory(String category) {
    switch (category) {
      case 'Market':
        return Icons.shopping_cart;
      case 'Yakıt':
        return Icons.local_gas_station;
      case 'Fatura':
        return Icons.receipt_long;
      case 'Eğlence':
        return Icons.movie;
      case 'Taksit':
        return Icons.credit_card;
      default:
        return Icons.more_horiz;
    }
  }
}
