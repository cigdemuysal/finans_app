import '../models/expense.dart';
import '../models/income.dart';
import '../models/installment.dart';
import '../models/investment.dart';
import '../utils/constants.dart';

// Ekranlardan bağımsız bütçe hesapları. Arayüz koduna dokunmadan test
// edilebilmeleri için burada toplanır.

/// [month] ayına düşen giderler.
List<Expense> expensesInMonth(List<Expense> expenses, DateTime month) {
  return expenses.where((e) => isSameMonth(e.date, month)).toList();
}

/// [month] ayında sayılan gelirler. Her ay tekrar eden gelirler başladıkları
/// aydan itibaren her ay sayılır.
List<Income> incomesInMonth(List<Income> incomes, DateTime month) {
  return incomes.where((i) {
    if (i.isRecurring) {
      final start = DateTime.tryParse(i.date);
      if (start == null) return false;
      final startMonth = DateTime(start.year, start.month);
      return !month.isBefore(startMonth);
    }
    return isSameMonth(i.date, month);
  }).toList();
}

/// [month] ayından önceki tüm ayların toplam bakiyesi (gelirler - giderler).
/// Pozitifse sonraki aya devir, negatifse devreden açık olarak gösterilir.
double balanceBeforeMonth({
  required List<Expense> expenses,
  required List<Income> incomes,
  required DateTime month,
}) {
  final currentMonth = DateTime(month.year, month.month);

  final fixedIncomeBeforeMonth = incomes
      .where((income) => !income.isRecurring)
      .where((income) {
        final date = DateTime.tryParse(income.date);
        return date != null &&
            DateTime(date.year, date.month).isBefore(currentMonth);
      })
      .fold<double>(0, (total, income) => total + income.amount);

  final recurringIncomeBeforeMonth = incomes
      .where((income) => income.isRecurring)
      .fold<double>(0, (total, income) {
        final startDate = DateTime.tryParse(income.date);
        if (startDate == null) return total;

        final startMonth = DateTime(startDate.year, startDate.month);
        if (!startMonth.isBefore(currentMonth)) return total;

        final elapsedMonths =
            (currentMonth.year - startMonth.year) * 12 +
            currentMonth.month -
            startMonth.month;
        return total + income.amount * elapsedMonths;
      });

  final expensesBeforeMonth = expenses
      .where((expense) {
        final date = DateTime.tryParse(expense.date);
        return date != null &&
            DateTime(date.year, date.month).isBefore(currentMonth);
      })
      .fold<double>(0, (total, expense) => total + expense.amount);

  return fixedIncomeBeforeMonth +
      recurringIncomeBeforeMonth -
      expensesBeforeMonth;
}

/// Ana sayfadaki aylık özet: o ayın gelir ve giderleri, önceki aylardan
/// devreden tutar ve bakiye.
class MonthSummary {
  MonthSummary._({
    required this.month,
    required this.expenses,
    required this.incomes,
    required this.previousBalance,
  });

  factory MonthSummary.calculate({
    required List<Expense> expenses,
    required List<Income> incomes,
    required DateTime month,
  }) {
    return MonthSummary._(
      month: month,
      expenses: expensesInMonth(expenses, month),
      incomes: incomesInMonth(incomes, month),
      previousBalance: balanceBeforeMonth(
        expenses: expenses,
        incomes: incomes,
        month: month,
      ),
    );
  }

  final DateTime month;
  final List<Expense> expenses;
  final List<Income> incomes;

  /// Önceki ayların toplam bakiyesi.
  final double previousBalance;

  double get carryoverIncome => previousBalance > 0 ? previousBalance : 0;

  double get carryoverDeficit => previousBalance < 0 ? -previousBalance : 0;

  double get totalIncome =>
      incomes.fold<double>(0, (total, income) => total + income.amount) +
      carryoverIncome;

  double get totalExpense =>
      expenses.fold<double>(0, (total, expense) => total + expense.amount) +
      carryoverDeficit;

  double get balance => totalIncome - totalExpense;
}

/// Henüz bitmemiş taksitler.
List<Installment> activeInstallments(List<Installment> installments) {
  return installments.where((i) => !i.isCompleted).toList();
}

/// Bitmemiş taksitlerin aylık toplamı.
double monthlyInstallmentTotal(List<Installment> installments) {
  return activeInstallments(installments)
      .fold(0, (total, i) => total + i.monthlyAmount);
}

/// Yatırımların toplam güncel değeri, maliyeti ve kâr/zararı.
class InvestmentSummary {
  InvestmentSummary(List<Investment> investments)
    : totalValue = investments.fold(0, (total, i) => total + i.currentValue),
      totalCost = investments.fold(0, (total, i) => total + i.totalCost);

  final double totalValue;
  final double totalCost;

  double get profitLoss => totalValue - totalCost;
}
