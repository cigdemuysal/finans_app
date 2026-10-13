import 'package:flutter/material.dart';

import '../logic/budget_calculator.dart';
import '../models/investment.dart';
import '../utils/constants.dart';
import '../utils/formatting.dart';

/// Yatırımlar sekmesi: toplam değer, kâr/zarar ve her yatırımın detayı.
class InvestmentsTab extends StatelessWidget {
  const InvestmentsTab({
    super.key,
    required this.investments,
    required this.scrollController,
    required this.onRefresh,
    required this.onInvestmentTap,
    required this.onUpdatePrice,
  });

  final List<Investment> investments;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(Investment investment) onInvestmentTap;
  final void Function(Investment investment) onUpdatePrice;

  @override
  Widget build(BuildContext context) {
    final summary = InvestmentSummary(investments);
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      interactive: true,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yatırımlarım',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (investments.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade800,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toplam Yatırım Değeri',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatMoney(summary.totalValue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatMoney(summary.profitLoss, signed: true)} '
                        'kar/zarar',
                        style: TextStyle(
                          color: summary.profitLoss >= 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              if (investments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Henüz yatırım eklenmedi. Altın, döviz veya gümüş ekleyebilirsin.',
                  ),
                ),

              ...investments.map((investment) {
                final isProfit = investment.profitLoss >= 0;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: colorForInvestmentType(
                                investment.type,
                              ).withValues(alpha: 0.15),
                              child: Icon(
                                iconForInvestmentType(investment.type),
                                color: colorForInvestmentType(investment.type),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    investment.type,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${formatQuantity(investment.quantity)} ${unitForInvestmentType(investment.type)} • '
                                    'Alış: ${formatMoney(investment.purchasePrice)}',
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => onInvestmentTap(investment),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Güncel Değer',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  formatMoney(investment.currentValue),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Kar/Zarar',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '${isProfit ? '+' : ''}'
                                  '${formatMoney(investment.profitLoss)} '
                                  '(%${formatNumber(investment.profitLossPercent, decimals: 1)})',
                                  style: TextStyle(
                                    color: isProfit ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => onUpdatePrice(investment),
                            icon: const Icon(Icons.price_change),
                            label: const Text('Güncel Fiyatı Gir'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text(
                  'Gösterilen fiyatlar bilgi amaçlıdır ve gecikmeli olabilir. '
                  'Dolar ve euro için TCMB döviz alış kuru kullanılır. '
                  'Bu uygulama yatırım tavsiyesi vermez.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
