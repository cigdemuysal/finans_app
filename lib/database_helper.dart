import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'shared_budget_service.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Şema her değiştiğinde (yeni tablo/kolon eklendiğinde) bu sürümü artır.
  static const int _dbVersion = 4;

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'finans.db');
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
  }

  // Eski bir cihazda daha önceden kısmi/eski şemayla oluşturulmuş bir
  // veritabanı olsa bile, eksik tabloları burada tamamlıyoruz.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _createAllTables(db);
  }

  Future<void> _createAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        description TEXT,
        amount REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS incomes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        description TEXT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        isRecurring INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS installments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        totalMonths INTEGER NOT NULL,
        paidMonths INTEGER NOT NULL DEFAULT 0,
        startDate TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        purchasePrice REAL NOT NULL,
        currentPrice REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Ortak bütçenin son görülen hâli. İnternet yokken bu kopya gösterilir.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shared_records_cache (
        household_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        id INTEGER NOT NULL,
        data TEXT NOT NULL,
        PRIMARY KEY (household_id, kind, id)
      )
    ''');

    // İnternet yokken ortak bütçeye yapılan ve henüz gönderilmemiş
    // değişiklikler. Bağlantı gelince sırayla gönderilir.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shared_pending_ops (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        household_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        op TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        data TEXT,
        client_ref TEXT
      )
    ''');
  }

  Future<String?> getActiveHouseholdId() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['active_household_id'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setActiveHouseholdId(String? householdId) async {
    final db = await database;
    if (householdId == null) {
      await db.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['active_household_id'],
      );
      return;
    }
    await db.insert('app_settings', {
      'key': 'active_household_id',
      'value': householdId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isSharedModeEnabled() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['shared_mode_enabled'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value'] == 'true';
  }

  Future<void> setSharedModeEnabled(bool enabled) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': 'shared_mode_enabled',
      'value': enabled.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getAppSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setAppSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Exports only the current device's private SQLite data. This is used only
  /// after the user explicitly confirms a one-time import into a shared budget.
  Future<Map<String, List<Map<String, dynamic>>>> getLocalSnapshot() async {
    final db = await database;
    Future<List<Map<String, dynamic>>> read(String table) => db.query(table);
    return {
      'expense': await read('expenses'),
      'income': await read('incomes'),
      'installment': await read('installments'),
      'investment': await read('investments'),
    };
  }

  // ==========================================================
  // YEDEKLEME
  // ==========================================================

  static const _backupTables = [
    'expenses',
    'incomes',
    'installments',
    'investments',
  ];

  /// Bu cihazdaki kişisel kayıtların tamamını tablo adına göre döndürür.
  Future<Map<String, List<Map<String, dynamic>>>> exportPersonalData() async {
    final db = await database;
    return {for (final table in _backupTables) table: await db.query(table)};
  }

  /// Kişisel kayıtları yedekteki kayıtlarla değiştirir. Tek bir işlem
  /// içinde çalışır; bir hata olursa hiçbir kayıt değişmez.
  Future<int> replacePersonalData(
    Map<String, List<Map<String, dynamic>>> tables,
  ) async {
    final db = await database;
    var count = 0;
    await db.transaction((txn) async {
      for (final table in _backupTables) {
        await txn.delete(table);
        for (final row in tables[table] ?? const <Map<String, dynamic>>[]) {
          await txn.insert(table, row);
          count++;
        }
      }
    });
    return count;
  }

  /// Bu cihazdaki kişisel kayıtların tamamını siler.
  Future<void> deleteAllPersonalData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in _backupTables) {
        await txn.delete(table);
      }
    });
  }

  // ==========================================================
  // ORTAK BÜTÇE: ÇEVRİMDIŞI KOPYA VE BEKLEYEN DEĞİŞİKLİKLER
  // ==========================================================

  Future<void> replaceSharedCache(
    String householdId,
    String kind,
    List<Map<String, dynamic>> records,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'shared_records_cache',
        where: 'household_id = ? AND kind = ?',
        whereArgs: [householdId, kind],
      );
      for (final record in records) {
        final data = Map<String, dynamic>.from(record)..remove('id');
        await txn.insert('shared_records_cache', {
          'household_id': householdId,
          'kind': kind,
          'id': record['id'] as int,
          'data': jsonEncode(data),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSharedCache(
    String householdId,
    String kind,
  ) async {
    final db = await database;
    final rows = await db.query(
      'shared_records_cache',
      where: 'household_id = ? AND kind = ?',
      whereArgs: [householdId, kind],
      orderBy: 'id DESC',
    );
    return rows.map((row) {
      final data = Map<String, dynamic>.from(
        jsonDecode(row['data'] as String) as Map,
      );
      data['id'] = row['id'] as int;
      return data;
    }).toList();
  }

  Future<void> addPendingOp(PendingSharedOp op) async {
    final db = await database;
    await db.insert('shared_pending_ops', op.toRow()..remove('seq'));
  }

  Future<List<PendingSharedOp>> getPendingOps(
    String householdId, {
    String? kind,
  }) async {
    final db = await database;
    final rows = await db.query(
      'shared_pending_ops',
      where: kind == null
          ? 'household_id = ?'
          : 'household_id = ? AND kind = ?',
      whereArgs: kind == null ? [householdId] : [householdId, kind],
      orderBy: 'seq ASC',
    );
    return rows.map(PendingSharedOp.fromRow).toList();
  }

  Future<int> countPendingOps(String householdId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM shared_pending_ops WHERE household_id = ?',
      [householdId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> deletePendingOp(int seq) async {
    final db = await database;
    await db.delete('shared_pending_ops', where: 'seq = ?', whereArgs: [seq]);
  }

  /// Henüz gönderilmemiş bir kaydı (geçici kimlikli) yerinde günceller.
  Future<bool> updatePendingInsert(
    String householdId,
    String kind,
    int recordId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    final changed = await db.update(
      'shared_pending_ops',
      {'data': jsonEncode(data)},
      where:
          "household_id = ? AND kind = ? AND record_id = ? AND op = 'insert'",
      whereArgs: [householdId, kind, recordId],
    );
    return changed > 0;
  }

  /// Bir kayda ait bekleyen tüm değişiklikleri siler.
  Future<int> deletePendingOpsForRecord(
    String householdId,
    String kind,
    int recordId,
  ) async {
    final db = await database;
    return db.delete(
      'shared_pending_ops',
      where: 'household_id = ? AND kind = ? AND record_id = ?',
      whereArgs: [householdId, kind, recordId],
    );
  }

  /// Ortak bütçenin bu cihazdaki kopyasını ve bekleyen değişiklikleri siler.
  Future<void> clearSharedLocalData() async {
    final db = await database;
    await db.delete('shared_records_cache');
    await db.delete('shared_pending_ops');
  }

  // ==========================================================
  // GİDERLER
  // ==========================================================

  Future<List<Map<String, dynamic>>> getExpenses() async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.getRecords('expense');
    }
    final db = await database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  Future<int> insertExpense(Map<String, dynamic> row) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.insertRecord('expense', row);
    }
    final db = await database;
    return await db.insert('expenses', row);
  }

  Future<int> updateExpense(int id, Map<String, dynamic> row) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.updateRecord('expense', id, row);
    }
    final db = await database;
    return await db.update('expenses', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteExpense(int id) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.deleteRecord('expense', id);
    }
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================
  // GELİRLER
  // ==========================================================

  Future<List<Map<String, dynamic>>> getIncomes() async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.getRecords('income');
    }
    final db = await database;
    return await db.query('incomes', orderBy: 'date DESC');
  }

  Future<int> insertIncome(Map<String, dynamic> row) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.insertRecord('income', row);
    }
    final db = await database;
    return await db.insert('incomes', row);
  }

  Future<int> updateIncome(int id, Map<String, dynamic> row) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.updateRecord('income', id, row);
    }
    final db = await database;
    return await db.update('incomes', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteIncome(int id) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.deleteRecord('income', id);
    }
    final db = await database;
    return await db.delete('incomes', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================
  // TAKSİTLER
  // ==========================================================

  Future<List<Map<String, dynamic>>> getInstallments() async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.getRecords('installment');
    }
    final db = await database;
    return await db.query('installments', orderBy: 'startDate DESC');
  }

  Future<int> insertInstallment(Map<String, dynamic> row) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.insertRecord('installment', row);
    }
    final db = await database;
    return await db.insert('installments', row);
  }

  Future<int> updateInstallment(int id, Map<String, dynamic> row) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.updateRecord('installment', id, row);
    }
    final db = await database;
    return await db.update(
      'installments',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteInstallment(int id) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.deleteRecord('installment', id);
    }
    final db = await database;
    return await db.delete('installments', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================================
  // YATIRIMLAR
  // ==========================================================

  Future<List<Map<String, dynamic>>> getInvestments() async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.getRecords('investment');
    }
    final db = await database;
    return await db.query('investments', orderBy: 'date DESC');
  }

  Future<int> insertInvestment(Map<String, dynamic> row) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.insertRecord('investment', row);
    }
    final db = await database;
    return await db.insert('investments', row);
  }

  Future<int> updateInvestment(int id, Map<String, dynamic> row) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.updateRecord('investment', id, row);
    }
    final db = await database;
    return await db.update(
      'investments',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteInvestment(int id) async {
    if (SharedBudgetService.hasActiveSharedBudget) {
      return SharedBudgetService.deleteRecord('investment', id);
    }
    final db = await database;
    return await db.delete('investments', where: 'id = ?', whereArgs: [id]);
  }
}

/// Ortak bütçeye internet yokken yapılan ve sırada bekleyen bir değişiklik.
class PendingSharedOp {
  const PendingSharedOp({
    this.seq,
    required this.householdId,
    required this.kind,
    required this.op,
    required this.recordId,
    this.data,
    this.clientRef,
  });

  final int? seq;
  final String householdId;
  final String kind;

  /// 'insert', 'update' veya 'delete'.
  final String op;

  /// Eklemelerde geçici (negatif) kimlik, diğerlerinde sunucudaki kimlik.
  final int recordId;
  final Map<String, dynamic>? data;

  /// Aynı kaydın sunucuya iki kez eklenmesini önleyen benzersiz anahtar.
  final String? clientRef;

  Map<String, dynamic> toRow() => {
    'seq': seq,
    'household_id': householdId,
    'kind': kind,
    'op': op,
    'record_id': recordId,
    'data': data == null ? null : jsonEncode(data),
    'client_ref': clientRef,
  };

  static PendingSharedOp fromRow(Map<String, dynamic> row) => PendingSharedOp(
    seq: row['seq'] as int?,
    householdId: row['household_id'] as String,
    kind: row['kind'] as String,
    op: row['op'] as String,
    recordId: row['record_id'] as int,
    data: row['data'] == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map),
    clientRef: row['client_ref'] as String?,
  );
}

/// Sunucudan (veya çevrimdışı kopyadan) gelen kayıtların üzerine henüz
/// gönderilmemiş değişiklikleri uygular; kullanıcı kendi yaptığı
/// değişiklikleri internet yokken de hemen görür.
List<Map<String, dynamic>> applyPendingOps(
  List<Map<String, dynamic>> records,
  List<PendingSharedOp> ops,
) {
  final result = records.map((r) => Map<String, dynamic>.from(r)).toList();
  for (final op in ops) {
    final index = result.indexWhere((r) => r['id'] == op.recordId);
    switch (op.op) {
      case 'insert':
        if (index == -1 && op.data != null) {
          result.insert(0, {...op.data!, 'id': op.recordId});
        }
      case 'update':
        if (index != -1 && op.data != null) {
          result[index] = {...op.data!, 'id': op.recordId};
        }
      case 'delete':
        if (index != -1) result.removeAt(index);
    }
  }
  return result;
}
