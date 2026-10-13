import 'package:flutter/material.dart';

import '../models/installment.dart';
import '../utils/formatting.dart';

/// Taksitler sekmesi: her taksidin ilerlemesi, aylık tutarı ve kalan borcu.
class InstallmentsTab extends StatelessWidget {
  const InstallmentsTab({
    super.key,
    required this.installments,
    required this.scrollController,
    required this.onRefresh,
    required this.onInstallmentTap,
    required this.onPayMonth,
  });

  final List<Installment> installments;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(Installment installment) onInstallmentTap;
  final void Function(Installment installment) onPayMonth;

  @override
  Widget build(BuildContext context) {
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
                'Taksitler',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (installments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Henüz taksit eklenmedi.'),
                ),
              ...installments.map((installment) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    installment.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(installment.category),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => onInstallmentTap(installment),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: installment.progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            color: installment.isCompleted
                                ? Colors.green
                                : Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${installment.paidMonths}/${installment.totalMonths} ay ödendi',
                            ),
                            Text(
                              'Aylık: ${formatMoney(installment.monthlyAmount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          installment.isCompleted
                              ? 'Taksit tamamlandı ✓'
                              : 'Kalan: ${formatMoney(installment.remainingAmount)}'
                                    ' (${installment.remainingMonths} ay)',
                          style: TextStyle(
                            color: installment.isCompleted
                                ? Colors.green
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (!installment.isCompleted) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => onPayMonth(installment),
                              icon: const Icon(Icons.check),
                              label: const Text('Bu Ayı Öde'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
