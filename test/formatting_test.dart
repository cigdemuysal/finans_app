import 'package:finans_app/utils/formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMoney', () {
    test('binlik ayırıcı nokta, ondalık ayırıcı virgül kullanır', () {
      expect(formatMoney(1234.5), '1.234,50 ₺');
      expect(formatMoney(1234567.891), '1.234.567,89 ₺');
      expect(formatMoney(0), '0,00 ₺');
      expect(formatMoney(999), '999,00 ₺');
    });

    test('negatif tutarları ve işareti doğru yazar', () {
      expect(formatMoney(-1500), '-1.500,00 ₺');
      expect(formatMoney(250, signed: true), '+250,00 ₺');
      expect(formatMoney(-250, signed: true), '-250,00 ₺');
      expect(formatMoney(-0.001), '0,00 ₺');
    });
  });

  test('formatNumber yüzde için tek ondalık yazar', () {
    expect(formatNumber(12.345, decimals: 1), '12,3');
  });

  test('formatQuantity gereksiz sıfırları atar', () {
    expect(formatQuantity(10), '10');
    expect(formatQuantity(2.5), '2,5');
    expect(formatQuantity(0.125), '0,125');
    expect(formatQuantity(1250), '1.250');
  });

  test('formatForInput düzenleme alanı için sade metin üretir', () {
    expect(formatForInput(1234.5), '1234,5');
    expect(formatForInput(850), '850');
    expect(formatForInput(0.125), '0,125');
    expect(inputTextFor(null), '');
  });

  group('parseAmount', () {
    test('Türkçe ve İngilizce yazımları okur', () {
      expect(parseAmount('1.234,50'), 1234.5);
      expect(parseAmount('1234,50'), 1234.5);
      expect(parseAmount('1234.50'), 1234.5);
      expect(parseAmount(' 850 ₺ '), 850);
      expect(parseAmount('0,125'), 0.125);
    });

    test('formatForInput çıktısını geri okur', () {
      for (final value in [0.125, 1234.5, 850.0, 2450.75]) {
        expect(parseAmount(formatForInput(value)), value);
      }
    });

    test('geçersiz metinde null döner', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
    });
  });
}
