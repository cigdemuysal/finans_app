import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../utils/constants.dart';
import '../utils/formatting.dart';

// ============================================================
// HARCAMA EKLE / DÜZENLE
// ============================================================

class AddExpensePage extends StatefulWidget {
  final Expense? expense;
  final Future<void> Function(Expense expense)? onSave;

  const AddExpensePage({super.key, this.expense, this.onSave});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  late final TextEditingController amountController;
  late final TextEditingController descriptionController;

  String selectedCategory = 'Market';
  late DateTime selectedDate;
  bool _isSaving = false;

  bool get isEditing => widget.expense != null;

  IconData get selectedIcon => Expense.iconForCategory(selectedCategory);

  @override
  void initState() {
    super.initState();

    amountController = TextEditingController(
      text: inputTextFor(widget.expense?.amount),
    );

    descriptionController = TextEditingController(
      text: widget.expense?.description ?? '',
    );

    selectedCategory = widget.expense?.category ?? 'Market';

    selectedDate = widget.expense != null
        ? (DateTime.tryParse(widget.expense!.date) ?? DateTime.now())
        : DateTime.now();
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

  Future<void> saveExpense() async {
    final amount = parseAmount(amountController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir tutar girin.')),
      );
      return;
    }

    final description = descriptionController.text.trim();

    final expense = Expense(
      id: widget.expense?.id,
      category: selectedCategory,
      description: description.isEmpty ? selectedCategory : description,
      amount: amount,
      date: selectedDate.toIso8601String(),
      icon: selectedIcon,
    );

    if (widget.onSave != null) {
      setState(() => _isSaving = true);
      try {
        await widget.onSave!(expense);
      } catch (error) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().contains('Socket') ||
                      error.toString().contains('host lookup')
                  ? 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.'
                  : 'Gider kaydedilemedi. Lütfen tekrar deneyin.',
            ),
          ),
        );
        return;
      }
    }

    if (mounted) Navigator.pop(context, expense);
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Harcamayı Düzenle' : 'Harcama Ekle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                hintText: 'Örn: 850',
                suffixText: '₺',
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
                hintText: 'Örn: Haftalık market alışverişi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : saveExpense,
                child: Text(
                  _isSaving
                      ? 'Kaydediliyor…'
                      : isEditing
                      ? 'Değişiklikleri Kaydet'
                      : 'Harcamayı Kaydet',
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
