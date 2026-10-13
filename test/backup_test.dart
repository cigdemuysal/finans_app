import 'package:finans_app/pages/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('geçerli yedek okunur, bilinmeyen tablolar yok sayılır', () {
    final tables = parseBackup({
      'format': 'acici-budget-backup',
      'version': 1,
      'tables': {
        'expenses': [
          {'id': 1, 'category': 'Market', 'amount': 10.0, 'date': '2026-10-01'},
        ],
        'unknown': [
          {'id': 1},
        ],
      },
    });
    expect(tables.keys, ['expenses', 'incomes', 'installments', 'investments']);
    expect(tables['expenses'], hasLength(1));
    expect(tables['incomes'], isEmpty);
  });

  test('başka bir dosya reddedilir', () {
    expect(() => parseBackup({'foo': 1}), throwsFormatException);
    expect(() => parseBackup([1, 2]), throwsFormatException);
  });

  test('daha yeni sürümle alınmış yedek reddedilir', () {
    expect(
      () => parseBackup({
        'format': 'acici-budget-backup',
        'version': 99,
        'tables': {},
      }),
      throwsFormatException,
    );
  });

  test('bozuk kayıt reddedilir', () {
    expect(
      () => parseBackup({
        'format': 'acici-budget-backup',
        'version': 1,
        'tables': {
          'expenses': ['bozuk'],
        },
      }),
      throwsFormatException,
    );
  });
}
