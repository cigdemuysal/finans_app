import 'package:finans_app/logic/budget_calculator.dart';
import 'package:finans_app/models/expense.dart';
import 'package:finans_app/models/income.dart';
import 'package:finans_app/models/installment.dart';
import 'package:finans_app/models/investment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Expense expense(double amount, String date) => Expense(
  category: 'Market',
  description: '',
  amount: amount,
  date: date,
  icon: Icons.shopping_cart,
);

Income income(double amount, String date, {bool recurring = false}) => Income(
  source: 'Maaş',
  description: '',
  amount: amount,
  date: date,
  isRecurring: recurring,
);

void main() {
  final october = DateTime(2026, 10);

  group('ay filtresi', () {
    test('yalnızca seçilen ayın giderleri sayılır', () {
      final result = expensesInMonth([
        expense(100, '2026-10-01T10:00:00'),
        expense(200, '2026-10-31T23:59:00'),
        expense(300, '2026-09-30T23:59:00'),
        expense(400, '2025-10-15T00:00:00'),
      ], october);
      expect(result.map((e) => e.amount), [100, 200]);
    });

    test('tekrar eden gelir başladığı aydan itibaren her ay sayılır', () {
      final incomes = [
        income(45000, '2026-08-15', recurring: true),
        income(5000, '2026-10-03'),
        income(7000, '2026-09-03'),
      ];
      expect(incomesInMonth(incomes, october).map((i) => i.amount), [
        45000,
        5000,
      ]);
      expect(incomesInMonth(incomes, DateTime(2026, 7)), isEmpty);
    });

    test('tarihi okunamayan kayıtlar sayılmaz', () {
      expect(expensesInMonth([expense(10, 'bozuk')], october), isEmpty);
      expect(
        incomesInMonth([income(10, 'bozuk', recurring: true)], october),
        isEmpty,
      );
    });
  });

  group('önceki aylardan devir', () {
    test('artan para sonraki aya devreder', () {
      final summary = MonthSummary.calculate(
        expenses: [expense(1000, '2026-09-10'), expense(500, '2026-10-05')],
        incomes: [income(3000, '2026-09-01')],
        month: october,
      );
      expect(summary.previousBalance, 2000);
      expect(summary.carryoverIncome, 2000);
      expect(summary.carryoverDeficit, 0);
      expect(summary.totalIncome, 2000);
      expect(summary.totalExpense, 500);
      expect(summary.balance, 1500);
    });

    test('eksi bakiye sonraki aya açık olarak geçer', () {
      final summary = MonthSummary.calculate(
        expenses: [expense(4000, '2026-09-10')],
        incomes: [income(1000, '2026-09-01'), income(2500, '2026-10-01')],
        month: october,
      );
      expect(summary.previousBalance, -3000);
      expect(summary.carryoverIncome, 0);
      expect(summary.carryoverDeficit, 3000);
      expect(summary.totalIncome, 2500);
      expect(summary.totalExpense, 3000);
      expect(summary.balance, -500);
    });

    test('tekrar eden gelir geçmiş her ay için devire eklenir', () {
      // Ağustos ve Eylül maaşları Ekim'e devreder; Ekim maaşı bu ayın geliri.
      final summary = MonthSummary.calculate(
        expenses: [expense(30000, '2026-09-20')],
        incomes: [income(20000, '2026-08-01', recurring: true)],
        month: october,
      );
      expect(summary.previousBalance, 10000);
      expect(summary.totalIncome, 30000);
      expect(summary.balance, 30000);
    });

    test('yıl değişiminde ay farkı doğru hesaplanır', () {
      final balance = balanceBeforeMonth(
        expenses: const [],
        incomes: [income(1000, '2025-11-10', recurring: true)],
        month: DateTime(2026, 2),
      );
      // Kasım, Aralık, Ocak = 3 ay
      expect(balance, 3000);
    });

    test('hiç kayıt yoksa her şey sıfır', () {
      final summary = MonthSummary.calculate(
        expenses: const [],
        incomes: const [],
        month: october,
      );
      expect(summary.balance, 0);
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 0);
    });
  });

  group('taksitler', () {
    Installment installment({int total = 12, int paid = 0}) => Installment(
      title: 'Telefon',
      category: 'Diğer',
      totalAmount: 12000,
      totalMonths: total,
      paidMonths: paid,
      startDate: '2026-01-01',
    );

    test('aylık tutar, kalan borç ve ilerleme hesaplanır', () {
      final i = installment(paid: 3);
      expect(i.monthlyAmount, 1000);
      expect(i.remainingAmount, 9000);
      expect(i.remainingMonths, 9);
      expect(i.progress, 0.25);
      expect(i.isCompleted, isFalse);
    });

    test('biten taksidin kalanı sıfırdır', () {
      final i = installment(paid: 12);
      expect(i.isCompleted, isTrue);
      expect(i.remainingAmount, 0);
      expect(i.progress, 1);
    });

    test('taksit sayısı sıfırsa bölme hatası olmaz', () {
      final i = installment(total: 0);
      expect(i.monthlyAmount, 0);
      expect(i.progress, 0);
    });

    test('aylık toplam yalnızca bitmemiş taksitleri sayar', () {
      final list = [installment(paid: 3), installment(paid: 12)];
      expect(activeInstallments(list), hasLength(1));
      expect(monthlyInstallmentTotal(list), 1000);
    });
  });

  group('yatırımlar', () {
    Investment investment(double qty, double buy, double now) => Investment(
      type: 'Altın',
      quantity: qty,
      purchasePrice: buy,
      currentPrice: now,
      date: '2026-01-01',
    );

    test('değer, maliyet ve kâr/zarar hesaplanır', () {
      final i = investment(10, 2000, 2500);
      expect(i.totalCost, 20000);
      expect(i.currentValue, 25000);
      expect(i.profitLoss, 5000);
      expect(i.profitLossPercent, 25);
    });

    test('toplam özet tüm yatırımları kapsar', () {
      final summary = InvestmentSummary([
        investment(10, 2000, 2500),
        investment(100, 30, 27),
      ]);
      expect(summary.totalValue, 27700);
      expect(summary.totalCost, 23000);
      expect(summary.profitLoss, 4700);
    });

    test('maliyeti sıfır olan yatırımda yüzde sıfırdır', () {
      expect(investment(10, 0, 5).profitLossPercent, 0);
    });
  });
}
