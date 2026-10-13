import 'package:finans_app/services/database_helper.dart';
import 'package:finans_app/services/shared_budget_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final db = DatabaseHelper.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedBudgetService.sharedModeEnabled = false;
    await databaseFactory.deleteDatabase(
      '${await getDatabasesPath()}/finans.db',
    );
  });

  setUp(() async {
    await db.deleteAllPersonalData();
    await db.clearSharedLocalData();
  });

  test('kişisel kayıt eklenir, güncellenir ve silinir', () async {
    final id = await db.insertExpense({
      'category': 'Market',
      'description': 'Ekmek',
      'amount': 25.5,
      'date': '2026-10-01',
    });
    await db.updateExpense(id, {
      'category': 'Market',
      'description': 'Ekmek',
      'amount': 30.0,
      'date': '2026-10-01',
    });
    expect((await db.getExpenses()).single['amount'], 30.0);

    await db.deleteExpense(id);
    expect(await db.getExpenses(), isEmpty);
  });

  test('yedek alınıp geri yüklendiğinde kayıtlar aynen geri gelir', () async {
    await db.insertExpense({
      'category': 'Yakıt',
      'description': '',
      'amount': 1500.0,
      'date': '2026-10-02',
    });
    await db.insertIncome({
      'source': 'Maaş',
      'description': '',
      'amount': 45000.0,
      'date': '2026-10-01',
      'isRecurring': 1,
    });
    final backup = await db.exportPersonalData();

    await db.deleteAllPersonalData();
    await db.insertExpense({
      'category': 'Eğlence',
      'description': 'Silinecek',
      'amount': 1.0,
      'date': '2026-10-03',
    });

    final restored = await db.replacePersonalData(backup);
    expect(restored, 2);
    expect((await db.getExpenses()).single['category'], 'Yakıt');
    expect((await db.getIncomes()).single['isRecurring'], 1);
  });

  test('bozuk yedek yüklenirse mevcut kayıtlar değişmez', () async {
    await db.insertExpense({
      'category': 'Market',
      'description': '',
      'amount': 10.0,
      'date': '2026-10-01',
    });

    await expectLater(
      db.replacePersonalData({
        'expenses': [
          {'olmayan_kolon': 1},
        ],
      }),
      throwsA(anything),
    );
    expect(await db.getExpenses(), hasLength(1));
  });

  test('ortak bütçe kopyası ve bekleyen değişiklikler saklanır', () async {
    await db.replaceSharedCache('h1', 'expense', [
      {'id': 7, 'amount': 70.0},
      {'id': 8, 'amount': 80.0},
    ]);
    expect(await db.getSharedCache('h1', 'expense'), [
      {'amount': 80.0, 'id': 8},
      {'amount': 70.0, 'id': 7},
    ]);
    expect(await db.getSharedCache('h2', 'expense'), isEmpty);

    await db.addPendingOp(
      const PendingSharedOp(
        householdId: 'h1',
        kind: 'expense',
        op: 'insert',
        recordId: -1,
        data: {'amount': 5.0},
        clientRef: 'ref1',
      ),
    );
    await db.addPendingOp(
      const PendingSharedOp(
        householdId: 'h1',
        kind: 'expense',
        op: 'delete',
        recordId: 7,
      ),
    );
    expect(await db.countPendingOps('h1'), 2);

    // Henüz gönderilmemiş kayıt düzenlenince sıradaki hâli değişir.
    expect(
      await db.updatePendingInsert('h1', 'expense', -1, {'amount': 6.0}),
      isTrue,
    );
    final ops = await db.getPendingOps('h1', kind: 'expense');
    expect(ops.first.data, {'amount': 6.0});
    expect(ops.map((o) => o.op), ['insert', 'delete']);

    final visible = applyPendingOps(
      await db.getSharedCache('h1', 'expense'),
      ops,
    );
    expect(visible.map((r) => r['id']), [-1, 8]);

    await db.deletePendingOpsForRecord('h1', 'expense', -1);
    expect(await db.countPendingOps('h1'), 1);

    await db.clearSharedLocalData();
    expect(await db.countPendingOps('h1'), 0);
    expect(await db.getSharedCache('h1', 'expense'), isEmpty);
  });

  test('ayarlar kaydedilip okunur', () async {
    await db.setAppSetting('deneme', 'evet');
    expect(await db.getAppSetting('deneme'), 'evet');
    await db.setActiveHouseholdId('h1');
    expect(await db.getActiveHouseholdId(), 'h1');
    await db.setActiveHouseholdId(null);
    expect(await db.getActiveHouseholdId(), isNull);
  });
}
