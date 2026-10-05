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
  static const int _dbVersion = 3;

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
