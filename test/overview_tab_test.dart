import 'package:finans_app/logic/budget_calculator.dart';
import 'package:finans_app/models/expense.dart';
import 'package:finans_app/models/income.dart';
import 'package:finans_app/pages/overview_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ana sayfa bakiyeyi ve işlemleri gösterir', (tester) async {
    final expense = Expense(
      category: 'Market',
      description: 'Haftalık alışveriş',
      amount: 1250.5,
      date: '2026-10-05',
      icon: Icons.shopping_cart,
    );
    final summary = MonthSummary.calculate(
      expenses: [expense],
      incomes: [
        Income(
          source: 'Maaş',
          description: '',
          amount: 45000,
          date: '2026-10-01',
          isRecurring: true,
        ),
      ],
      month: DateTime(2026, 10),
    );
    Expense? tapped;
    var monthChange = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewTab(
            summary: summary,
            activeInstallmentCount: 2,
            monthlyInstallmentTotal: 1500,
            scrollController: ScrollController(),
            onRefresh: () async {},
            onChangeMonth: (offset) => monthChange += offset,
            onExpenseTap: (e) => tapped = e,
            onIncomeTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(find.text('43.749,50 ₺'), findsOneWidget);
    expect(find.text('2 aktif taksit'), findsOneWidget);
    expect(find.text('Aylık toplam: 1.500,00 ₺'), findsOneWidget);
    expect(find.text('-1.250,50 ₺'), findsOneWidget);
    expect(find.text('+45.000,00 ₺'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(monthChange, 1);

    await tester.ensureVisible(find.text('Market'));
    final marketCard = find.ancestor(
      of: find.text('Market'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: marketCard, matching: find.byIcon(Icons.more_vert)),
    );
    expect(tapped, same(expense));
  });
}
