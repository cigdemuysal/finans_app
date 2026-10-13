import 'package:flutter/material.dart';

// ============================================================
// YARDIMCI SABİTLER
// ============================================================

const List<String> turkishMonths = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const List<String> expenseCategories = [
  'Market',
  'Yakıt',
  'Fatura',
  'Eğlence',
  'Taksit',
  'Diğer',
];

const List<String> investmentTypes = [
  'Altın',
  'Euro',
  'Dolar',
  'Gümüş',
  'Diğer',
];

IconData iconForInvestmentType(String type) {
  switch (type) {
    case 'Altın':
      return Icons.monetization_on;
    case 'Euro':
      return Icons.euro;
    case 'Dolar':
      return Icons.attach_money;
    case 'Gümüş':
      return Icons.circle;
    default:
      return Icons.trending_up;
  }
}

Color colorForInvestmentType(String type) {
  switch (type) {
    case 'Altın':
      return Colors.amber.shade700;
    case 'Euro':
      return Colors.indigo;
    case 'Dolar':
      return Colors.green.shade700;
    case 'Gümüş':
      return Colors.blueGrey;
    default:
      return Colors.purple;
  }
}

// Altın/gümüş gram ile, dövizler birim (adet) ile tutulur.
String unitForInvestmentType(String type) {
  if (type == 'Altın' || type == 'Gümüş') return 'gr';
  return 'birim';
}

String formatMonth(DateTime date) {
  return '${turkishMonths[date.month - 1]} ${date.year}';
}

String formatDate(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  return '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year}';
}

bool isSameMonth(String isoDate, DateTime month) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return false;
  return d.year == month.year && d.month == month.month;
}
