import 'package:flutter/material.dart';

import '../models/income.dart';
import '../utils/constants.dart';
import '../utils/formatting.dart';

// ============================================================
// GELİR EKLE / DÜZENLE
// ============================================================

class AddIncomePage extends StatefulWidget {
  final Income? income;

  const AddIncomePage({super.key, this.income});

  @override
  State<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends State<AddIncomePage> {
  late final TextEditingController sourceController;
  late final TextEditingController amountController;
  late final TextEditingController descriptionController;

  late DateTime selectedDate;
  bool isRecurring = false;

  bool get isEditing => widget.income != null;

  @override
  void initState() {
    super.initState();

    sourceController = TextEditingController(text: widget.income?.source ?? '');
    amountController = TextEditingController(
      text: inputTextFor(widget.income?.amount),
    );
    descriptionController = TextEditingController(
      text: widget.income?.description ?? '',
    );

    selectedDate = widget.income != null
        ? (DateTime.tryParse(widget.income!.date) ?? DateTime.now())
        : DateTime.now();

    isRecurring = widget.income?.isRecurring ?? false;
  }

  Future<void> pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result != null) {
      setState(() => selectedDate = result);
    }
  }

  void saveIncome() {
    final source = sourceController.text.trim();
    final amount = parseAmount(amountController.text);

    if (source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir gelir kaynağı girin.')),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir tutar girin.')),
      );
      return;
    }

    final income = Income(
      id: widget.income?.id,
      source: source,
      description: descriptionController.text.trim(),
      amount: amount,
      date: selectedDate.toIso8601String(),
      isRecurring: isRecurring,
    );

    Navigator.pop(context, income);
  }

  @override
  void dispose() {
    sourceController.dispose();
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Geliri Düzenle' : 'Gelir Ekle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kaynak',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sourceController,
              decoration: const InputDecoration(
                hintText: 'Örn: Maaş, Ek İş, Kira Geliri',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tutar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Örn: 45000',
                suffixText: '₺',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tarih',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                child: Text(formatDate(selectedDate.toIso8601String())),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Açıklama',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                hintText: 'Opsiyonel not',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Her ay tekrar eden gelir'),
              subtitle: const Text('Örn: maaş gibi her ay otomatik sayılır'),
              value: isRecurring,
              onChanged: (value) => setState(() => isRecurring = value),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: saveIncome,
                child: Text(
                  isEditing ? 'Değişiklikleri Kaydet' : 'Geliri Kaydet',
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
