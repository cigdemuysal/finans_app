import 'package:flutter/material.dart';

import '../logic/budget_calculator.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../utils/constants.dart';
import '../utils/formatting.dart';

/// Ana sayfa: ay seçici, aylık bakiye, aktif taksit özeti ve o ayın işlemleri.
class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.summary,
    required this.activeInstallmentCount,
    required this.monthlyInstallmentTotal,
    required this.scrollController,
    required this.onRefresh,
    required this.onChangeMonth,
    required this.onExpenseTap,
    required this.onIncomeTap,
  });

  final MonthSummary summary;
  final int activeInstallmentCount;
  final double monthlyInstallmentTotal;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(int offset) onChangeMonth;
  final void Function(Expense expense) onExpenseTap;
  final void Function(Income income) onIncomeTap;

  @override
  Widget build(BuildContext context) {
    // Gelir + gider işlemlerini tarihe göre tek listede birleştir
    final items = <_TransactionItem>[
      ...summary.expenses.map(
        (e) => _TransactionItem(
          title: e.category,
          subtitle: e.description,
          amount: -e.amount,
          date: e.date,
          icon: e.icon,
          color: Colors.red,
          onTap: () => onExpenseTap(e),
        ),
      ),
      ...summary.incomes.map(
        (i) => _TransactionItem(
          title: i.source,
          subtitle: i.description,
          amount: i.amount,
          date: i.date,
          icon: Icons.attach_money,
          color: Colors.green,
          onTap: () => onIncomeTap(i),
        ),
      ),
      if (summary.carryoverIncome > 0)
        _TransactionItem(
          title: 'Geçen aydan devir',
          subtitle: 'Önceki aylardan kalan bakiye',
          amount: summary.carryoverIncome,
          date:
              '${summary.month.year.toString().padLeft(4, '0')}-'
              '${summary.month.month.toString().padLeft(2, '0')}-01',
          icon: Icons.call_received,
          color: Colors.green,
          onTap: () {},
        ),
      if (summary.carryoverDeficit > 0)
        _TransactionItem(
          title: 'Geçen aydan devreden açık',
          subtitle: 'Önceki aylardan kalan eksi bakiye',
          amount: -summary.carryoverDeficit,
          date:
              '${summary.month.year.toString().padLeft(4, '0')}-'
              '${summary.month.month.toString().padLeft(2, '0')}-01',
          icon: Icons.call_received,
          color: Colors.red,
          onTap: () {},
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      interactive: true,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          // Son işlem kartı, alttaki Ekle düğmesinin arkasında kalmasın.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // ==================================================
            // AY SEÇİCİ
            // ==================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => onChangeMonth(-1),
                ),
                Text(
                  formatMonth(summary.month),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => onChangeMonth(1),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ==================================================
            // BAKİYE
            // ==================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bu Ayki Bakiye',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(summary.balance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gelir',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formatMoney(summary.totalIncome),
                              style: TextStyle(
                                color: Colors.greenAccent.shade100,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gider',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formatMoney(summary.totalExpense),
                              style: TextStyle(
                                color: Colors.red.shade100,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (activeInstallmentCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$activeInstallmentCount aktif taksit'),
                          Text(
                            'Aylık toplam: ${formatMoney(monthlyInstallmentTotal)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ==================================================
            // İŞLEMLER
            // ==================================================
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bu Ayki İşlemler',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Bu ay için henüz işlem yok.'),
              ),

            ...items.map((item) {
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(item.icon)),
                  title: Text(item.title),
                  subtitle: Text(
                    item.subtitle.isEmpty
                        ? formatDate(item.date)
                        : '${item.subtitle} • ${formatDate(item.date)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatMoney(item.amount, signed: true),
                        style: TextStyle(
                          color: item.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: item.onTap,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TransactionItem {
  final String title;
  final String subtitle;
  final double amount;
  final String date;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _TransactionItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
