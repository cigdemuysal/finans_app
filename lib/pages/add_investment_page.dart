import 'package:flutter/material.dart';

import '../models/investment.dart';
import '../utils/constants.dart';
import '../utils/formatting.dart';

// ============================================================
// YATIRIM EKLE / DÜZENLE
// ============================================================

class AddInvestmentPage extends StatefulWidget {
  final Investment? investment;

  const AddInvestmentPage({super.key, this.investment});

  @override
  State<AddInvestmentPage> createState() => _AddInvestmentPageState();
}

class _AddInvestmentPageState extends State<AddInvestmentPage> {
  late final TextEditingController quantityController;
  late final TextEditingController purchasePriceController;
  late final TextEditingController currentPriceController;

  String selectedType = 'Altın';
  late DateTime selectedDate;

  bool get isEditing => widget.investment != null;

  @override
  void initState() {
    super.initState();

    quantityController = TextEditingController(
      text: inputTextFor(widget.investment?.quantity),
    );
    purchasePriceController = TextEditingController(
      text: inputTextFor(widget.investment?.purchasePrice),
    );
    currentPriceController = TextEditingController(
      text: inputTextFor(
        widget.investment?.currentPrice ?? widget.investment?.purchasePrice,
      ),
    );

    selectedType = widget.investment?.type ?? 'Altın';

    selectedDate = widget.investment != null
        ? (DateTime.tryParse(widget.investment!.date) ?? DateTime.now())
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

  void saveInvestment() {
    final quantity = parseAmount(quantityController.text);
    final purchasePrice = parseAmount(purchasePriceController.text);
    final currentPriceText = currentPriceController.text.trim();
    final currentPrice = currentPriceText.isEmpty
        ? purchasePrice
        : parseAmount(currentPriceText);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir miktar girin.')),
      );
      return;
    }

    if (purchasePrice == null || purchasePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir alış fiyatı girin.')),
      );
      return;
    }

    if (currentPrice == null || currentPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir güncel fiyat girin.')),
      );
      return;
    }

    final investment = Investment(
      id: widget.investment?.id,
      type: selectedType,
      quantity: quantity,
      purchasePrice: purchasePrice,
      currentPrice: currentPrice,
      date: selectedDate.toIso8601String(),
    );

    Navigator.pop(context, investment);
  }

  @override
  void dispose() {
    quantityController.dispose();
    purchasePriceController.dispose();
    currentPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Yatırımı Düzenle' : 'Yatırım Ekle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tür',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: investmentTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconForInvestmentType(t), size: 18),
                          const SizedBox(width: 8),
                          Text(t),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedType = value);
                }
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Miktar (${unitForInvestmentType(selectedType)})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: selectedType == 'Altın' || selectedType == 'Gümüş'
                    ? 'Örn: 10 (gram)'
                    : 'Örn: 500',
                suffixText: unitForInvestmentType(selectedType),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Alış Fiyatı (birim başına)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: purchasePriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Örn: 2450',
                suffixText: '₺',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Güncel Fiyat (birim başına)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: currentPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Boş bırakılırsa alış fiyatı kullanılır',
                suffixText: '₺',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Alış Tarihi',
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
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: saveInvestment,
                child: Text(
                  isEditing ? 'Değişiklikleri Kaydet' : 'Yatırımı Kaydet',
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
