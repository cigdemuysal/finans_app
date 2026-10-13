import 'package:flutter/material.dart';

import '../models/installment.dart';
import '../utils/constants.dart';
import '../utils/formatting.dart';

// ============================================================
// TAKSİT EKLE / DÜZENLE
// ============================================================

class AddInstallmentPage extends StatefulWidget {
  final Installment? installment;

  const AddInstallmentPage({super.key, this.installment});

  @override
  State<AddInstallmentPage> createState() => _AddInstallmentPageState();
}

class _AddInstallmentPageState extends State<AddInstallmentPage> {
  late final TextEditingController titleController;
  late final TextEditingController totalAmountController;
  late final TextEditingController totalMonthsController;
  late final TextEditingController paidMonthsController;

  String selectedCategory = 'Diğer';
  late DateTime startDate;

  bool get isEditing => widget.installment != null;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.installment?.title ?? '',
    );
    totalAmountController = TextEditingController(
      text: inputTextFor(widget.installment?.totalAmount),
    );
    totalMonthsController = TextEditingController(
      text: widget.installment?.totalMonths.toString() ?? '',
    );
    paidMonthsController = TextEditingController(
      text: widget.installment?.paidMonths.toString() ?? '0',
    );

    selectedCategory = widget.installment?.category ?? 'Diğer';

    startDate = widget.installment != null
        ? (DateTime.tryParse(widget.installment!.startDate) ?? DateTime.now())
        : DateTime.now();
  }

  Future<void> pickStartDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result != null) {
      setState(() => startDate = result);
    }
  }

  void saveInstallment() {
    final title = titleController.text.trim();
    final totalAmount = parseAmount(totalAmountController.text);
    final totalMonths = int.tryParse(totalMonthsController.text);
    final paidMonths = int.tryParse(paidMonthsController.text) ?? 0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir taksit adı girin.')),
      );
      return;
    }

    if (totalAmount == null || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir toplam tutar girin.')),
      );
      return;
    }

    if (totalMonths == null || totalMonths <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir taksit sayısı girin.'),
        ),
      );
      return;
    }

    if (paidMonths < 0 || paidMonths > totalMonths) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödenen taksit sayısı geçersiz.')),
      );
      return;
    }

    final installment = Installment(
      id: widget.installment?.id,
      title: title,
      category: selectedCategory,
      totalAmount: totalAmount,
      totalMonths: totalMonths,
      paidMonths: paidMonths,
      startDate: startDate.toIso8601String(),
    );

    Navigator.pop(context, installment);
  }

  @override
  void dispose() {
    titleController.dispose();
    totalAmountController.dispose();
    totalMonthsController.dispose();
    paidMonthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Taksiti Düzenle' : 'Taksit Ekle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Taksit Adı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Örn: Telefon, Beyaz Eşya',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kategori',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: expenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Toplam Tutar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: totalAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Örn: 12000',
                suffixText: '₺',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Taksit Sayısı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: totalMonthsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Örn: 12',
                suffixText: 'ay',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Şu Ana Kadar Ödenen Taksit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: paidMonthsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Örn: 0',
                suffixText: 'ay',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Başlangıç Tarihi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: pickStartDate,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                child: Text(formatDate(startDate.toIso8601String())),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: saveInstallment,
                child: Text(
                  isEditing ? 'Değişiklikleri Kaydet' : 'Taksiti Kaydet',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
