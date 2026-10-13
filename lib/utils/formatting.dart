// Türkiye'de alışılmış sayı biçimi: binlik ayırıcı nokta, ondalık ayırıcı virgül.
// Örn: 1234.5 -> "1.234,50 ₺"

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Sayıyı Türkçe biçimde yazar. [decimals] kadar ondalık hane gösterir.
String formatNumber(double value, {int decimals = 2}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = _groupThousands(parts[0]);
  final text = parts.length > 1 ? '$whole,${parts[1]}' : whole;
  return negative && fixed.replaceAll(RegExp(r'[0.]'), '').isNotEmpty
      ? '-$text'
      : text;
}

/// Tutarı "1.234,50 ₺" biçiminde yazar. [signed] true ise pozitif tutarların
/// önüne "+" koyar.
String formatMoney(double value, {bool signed = false}) {
  final text = formatNumber(value);
  final sign = signed && value >= 0 ? '+' : '';
  return '$sign$text ₺';
}

/// Miktar (gram, adet) gibi değerleri gereksiz sıfırlar olmadan yazar.
/// Örn: 10.0 -> "10", 2.5 -> "2,5", 1250 -> "1.250"
String formatQuantity(double value) {
  var text = formatNumber(value, decimals: 3);
  if (text.contains(',')) {
    text = text.replaceFirst(RegExp(r',?0+$'), '');
  }
  return text;
}

/// Düzenleme alanlarına konacak sade metin. Örn: 1234.5 -> "1234,5"
String formatForInput(double value) {
  var text = value.toStringAsFixed(4);
  text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  return text.replaceAll('.', ',');
}

/// Boş olabilen değerler için [formatForInput].
String inputTextFor(double? value) =>
    value == null ? '' : formatForInput(value);

/// Kullanıcının yazdığı tutarı okur. "1.234,50", "1234,50" ve "1234.50"
/// biçimlerini kabul eder. Okunamazsa null döner.
double? parseAmount(String input) {
  var text = input.trim().replaceAll('₺', '').replaceAll(' ', '');
  if (text.isEmpty) return null;
  if (text.contains(',')) {
    // Virgül varsa ondalık ayırıcıdır; noktalar binlik ayırıcıdır.
    text = text.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(text);
}
