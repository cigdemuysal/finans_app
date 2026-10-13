import 'package:finans_app/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';

PendingSharedOp op(String type, int id, [Map<String, dynamic>? data]) =>
    PendingSharedOp(
      householdId: 'h1',
      kind: 'expense',
      op: type,
      recordId: id,
      data: data,
    );

void main() {
  final records = [
    {'id': 2, 'amount': 20.0},
    {'id': 1, 'amount': 10.0},
  ];

  test('bekleyen ekleme listenin başına geçici kimlikle eklenir', () {
    final result = applyPendingOps(records, [
      op('insert', -5, {'amount': 99.0}),
    ]);
    expect(result.first, {'amount': 99.0, 'id': -5});
    expect(result, hasLength(3));
  });

  test('bekleyen güncelleme ve silme uygulanır', () {
    final result = applyPendingOps(records, [
      op('update', 1, {'amount': 15.0}),
      op('delete', 2),
    ]);
    expect(result, [
      {'amount': 15.0, 'id': 1},
    ]);
  });

  test('sunucuya ulaşmış bir ekleme ikinci kez gösterilmez', () {
    final result = applyPendingOps(
      [
        {'id': -5, 'amount': 99.0},
      ],
      [
        op('insert', -5, {'amount': 99.0}),
      ],
    );
    expect(result, hasLength(1));
  });

  test('orijinal liste değiştirilmez', () {
    applyPendingOps(records, [op('delete', 1)]);
    expect(records, hasLength(2));
  });

  test('PendingSharedOp veritabanı satırına dönüşüp geri okunur', () {
    final original = PendingSharedOp(
      seq: 3,
      householdId: 'h1',
      kind: 'income',
      op: 'insert',
      recordId: -7,
      data: {'source': 'Maaş', 'amount': 45000.0},
      clientRef: 'abc',
    );
    final copy = PendingSharedOp.fromRow(original.toRow());
    expect(copy.seq, 3);
    expect(copy.kind, 'income');
    expect(copy.recordId, -7);
    expect(copy.data, {'source': 'Maaş', 'amount': 45000.0});
    expect(copy.clientRef, 'abc');
  });
}
