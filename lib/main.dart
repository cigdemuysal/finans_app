import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'shared_budget_page.dart';
import 'shared_budget_service.dart';
import 'tcmb_rates_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedBudgetService.initialize();
  SharedBudgetService.activeHouseholdId =
      await DatabaseHelper.instance.getActiveHouseholdId();
  SharedBudgetService.sharedModeEnabled =
      await DatabaseHelper.instance.isSharedModeEnabled();
  runApp(const FinansApp());
}

// Masaüstünde (Windows/macOS/Linux) mouse ile sürükleyerek de
// kaydırabilmek için varsayılan scroll davranışını genişletiyoruz.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class FinansApp extends StatelessWidget {
  const FinansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Açıcı Budget',
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RootPage(),
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri == null) return null;
        final isJoinLink = uri.path == '/join' || uri.host == 'join';
        final isAuthCallback =
            uri.scheme == 'acici-budget' && uri.host == 'auth-callback';
        if (!isJoinLink && !isAuthCallback) {
          return null;
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => RootPage(
            initialTab: 3,
            inviteCode: isJoinLink ? uri.queryParameters['code'] : null,
          ),
        );
      },
    );
  }
}

// ============================================================
// YARDIMCI SABİTLER
// ============================================================

const List<String> turkishMonths = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const List<String> expenseCategories = [
  'Market',
  'Yakıt',
  'Fatura',
  'Eğlence',
  'Taksit',
  'Diğer',
];

const List<String> investmentTypes = [
  'Altın',
  'Euro',
  'Dolar',
  'Gümüş',
  'Diğer',
];

IconData iconForInvestmentType(String type) {
  switch (type) {
    case 'Altın':
      return Icons.monetization_on;
    case 'Euro':
      return Icons.euro;
    case 'Dolar':
      return Icons.attach_money;
    case 'Gümüş':
      return Icons.circle;
    default:
      return Icons.trending_up;
  }
}

Color colorForInvestmentType(String type) {
  switch (type) {
    case 'Altın':
      return Colors.amber.shade700;
    case 'Euro':
      return Colors.indigo;
    case 'Dolar':
      return Colors.green.shade700;
    case 'Gümüş':
      return Colors.blueGrey;
    default:
      return Colors.purple;
  }
}

// Altın/gümüş gram ile, dövizler birim (adet) ile tutulur.
String unitForInvestmentType(String type) {
  if (type == 'Altın' || type == 'Gümüş') return 'gr';
  return 'birim';
}

String formatMonth(DateTime date) {
  return '${turkishMonths[date.month - 1]} ${date.year}';
}

String formatDate(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  return '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year}';
}

bool isSameMonth(String isoDate, DateTime month) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return false;
  return d.year == month.year && d.month == month.month;
}

// ============================================================
// HARCAMA MODELİ
// ============================================================

class Expense {
  final int? id;
  final String category;
  final String description;
  final double amount;
  final String date;
  final IconData icon;

  const Expense({
    this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'date': date,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      category: map['category'] as String,
      description: (map['description'] ?? '') as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      icon: iconForCategory(map['category'] as String),
    );
  }

  static IconData iconForCategory(String category) {
    switch (category) {
      case 'Market':
        return Icons.shopping_cart;
      case 'Yakıt':
        return Icons.local_gas_station;
      case 'Fatura':
        return Icons.receipt_long;
      case 'Eğlence':
        return Icons.movie;
      case 'Taksit':
        return Icons.credit_card;
      default:
        return Icons.more_horiz;
    }
  }
}

// ============================================================
// GELİR MODELİ
// ============================================================

class Income {
  final int? id;
  final String source;
  final String description;
  final double amount;
  final String date;
  final bool isRecurring;

  const Income({
    this.id,
    required this.source,
    required this.description,
    required this.amount,
    required this.date,
    required this.isRecurring,
  });

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'description': description,
      'amount': amount,
      'date': date,
      'isRecurring': isRecurring ? 1 : 0,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'] as int?,
      source: map['source'] as String,
      description: (map['description'] ?? '') as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      isRecurring: (map['isRecurring'] as int) == 1,
    );
  }
}

// ============================================================
// TAKSİT MODELİ
// ============================================================

class Installment {
  final int? id;
  final String title;
  final String category;
  final double totalAmount;
  final int totalMonths;
  final int paidMonths;
  final String startDate;

  const Installment({
    this.id,
    required this.title,
    required this.category,
    required this.totalAmount,
    required this.totalMonths,
    required this.paidMonths,
    required this.startDate,
  });

  double get monthlyAmount => totalMonths == 0 ? 0 : totalAmount / totalMonths;

  double get remainingAmount {
    final r = totalAmount - (monthlyAmount * paidMonths);
    return r < 0 ? 0 : r;
  }

  int get remainingMonths => totalMonths - paidMonths;

  bool get isCompleted => paidMonths >= totalMonths;

  double get progress {
    if (totalMonths == 0) return 0;
    final p = paidMonths / totalMonths;
    return p.clamp(0, 1);
  }

  Installment copyWith({int? paidMonths}) {
    return Installment(
      id: id,
      title: title,
      category: category,
      totalAmount: totalAmount,
      totalMonths: totalMonths,
      paidMonths: paidMonths ?? this.paidMonths,
      startDate: startDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'totalAmount': totalAmount,
      'totalMonths': totalMonths,
      'paidMonths': paidMonths,
      'startDate': startDate,
    };
  }

  factory Installment.fromMap(Map<String, dynamic> map) {
    return Installment(
      id: map['id'] as int?,
      title: map['title'] as String,
      category: map['category'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      totalMonths: map['totalMonths'] as int,
      paidMonths: map['paidMonths'] as int,
      startDate: map['startDate'] as String,
    );
  }
}

// ============================================================
// YATIRIM MODELİ
// ============================================================

class Investment {
  final int? id;
  final String type;
  final double quantity;
  final double purchasePrice;
  final double currentPrice;
  final String date;

  const Investment({
    this.id,
    required this.type,
    required this.quantity,
    required this.purchasePrice,
    required this.currentPrice,
    required this.date,
  });

  double get totalCost => quantity * purchasePrice;
  double get currentValue => quantity * currentPrice;
  double get profitLoss => currentValue - totalCost;
  double get profitLossPercent =>
      totalCost == 0 ? 0 : (profitLoss / totalCost) * 100;

  Investment copyWith({double? currentPrice}) {
    return Investment(
      id: id,
      type: type,
      quantity: quantity,
      purchasePrice: purchasePrice,
      currentPrice: currentPrice ?? this.currentPrice,
      date: date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'currentPrice': currentPrice,
      'date': date,
    };
  }

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'] as int?,
      type: map['type'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      purchasePrice: (map['purchasePrice'] as num).toDouble(),
      currentPrice: (map['currentPrice'] as num).toDouble(),
      date: map['date'] as String,
    );
  }
}

// ============================================================
// KÖK SAYFA (BOTTOM NAV + TÜM VERİ YÖNETİMİ)
// ============================================================

class RootPage extends StatefulWidget {
  const RootPage({super.key, this.initialTab = 0, this.inviteCode});

  final int initialTab;
  final String? inviteCode;

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int currentTab = 0;

  bool isLoading = true;
  bool _startupRatesChecked = false;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<Expense> expenses = [];
  List<Income> incomes = [];
  List<Installment> installments = [];
  List<Investment> investments = [];

  // Her sekme kendi scroll pozisyonunu tutar; Scrollbar bileşenleri
  // görünür kaydırma çubuğu için bunları kullanır.
  final ScrollController overviewScrollController = ScrollController();
  final ScrollController installmentsScrollController = ScrollController();
  final ScrollController investmentsScrollController = ScrollController();

  // ==========================================================
  // AY BAZLI FİLTRELENMİŞ LİSTELER
  // ==========================================================

  List<Expense> get expensesForMonth {
    return expenses.where((e) => isSameMonth(e.date, selectedMonth)).toList();
  }

  List<Income> get incomesForMonth {
    return incomes.where((i) {
      if (i.isRecurring) {
        final start = DateTime.tryParse(i.date);
        if (start == null) return false;
        final startMonth = DateTime(start.year, start.month);
        return !selectedMonth.isBefore(startMonth);
      }
      return isSameMonth(i.date, selectedMonth);
    }).toList();
  }

  List<Installment> get activeInstallments {
    return installments.where((i) => !i.isCompleted).toList();
  }

  double get previousPeriodBalance {
    final currentMonth = DateTime(selectedMonth.year, selectedMonth.month);

    final fixedIncomeBeforeMonth = incomes
        .where((income) => !income.isRecurring)
        .where((income) {
          final date = DateTime.tryParse(income.date);
          return date != null &&
              DateTime(date.year, date.month).isBefore(currentMonth);
        })
        .fold<double>(0, (total, income) => total + income.amount);

    final recurringIncomeBeforeMonth = incomes
        .where((income) => income.isRecurring)
        .fold<double>(0, (total, income) {
          final startDate = DateTime.tryParse(income.date);
          if (startDate == null) return total;

          final startMonth = DateTime(startDate.year, startDate.month);
          if (!startMonth.isBefore(currentMonth)) return total;

          final elapsedMonths =
              (currentMonth.year - startMonth.year) * 12 +
              currentMonth.month -
              startMonth.month;
          return total + income.amount * elapsedMonths;
        });

    final expensesBeforeMonth = expenses
        .where((expense) {
          final date = DateTime.tryParse(expense.date);
          return date != null &&
              DateTime(date.year, date.month).isBefore(currentMonth);
        })
        .fold<double>(0, (total, expense) => total + expense.amount);

    return fixedIncomeBeforeMonth +
        recurringIncomeBeforeMonth -
        expensesBeforeMonth;
  }

  double get carryoverIncome =>
      previousPeriodBalance > 0 ? previousPeriodBalance : 0;

  double get carryoverDeficit =>
      previousPeriodBalance < 0 ? -previousPeriodBalance : 0;

  double get totalIncome {
    return incomesForMonth.fold<double>(
          0,
          (total, income) => total + income.amount,
        ) +
        carryoverIncome;
  }

  double get totalExpense {
    return expensesForMonth.fold<double>(
          0,
          (total, expense) => total + expense.amount,
        ) +
        carryoverDeficit;
  }

  double get balance => totalIncome - totalExpense;

  double get pendingInstallmentTotal {
    return activeInstallments.fold(0, (total, i) => total + i.monthlyAmount);
  }

  double get totalInvestmentValue {
    return investments.fold(0, (total, i) => total + i.currentValue);
  }

  double get totalInvestmentCost {
    return investments.fold(0, (total, i) => total + i.totalCost);
  }

  double get totalInvestmentProfitLoss =>
      totalInvestmentValue - totalInvestmentCost;

  @override
  void initState() {
    super.initState();
    currentTab = widget.initialTab;
    loadAll();
  }

  @override
  void dispose() {
    overviewScrollController.dispose();
    installmentsScrollController.dispose();
    investmentsScrollController.dispose();
    super.dispose();
  }

  // ==========================================================
  // TÜM VERİYİ YÜKLE
  // ==========================================================

  Future<void> loadAll() async {
    final expenseData = await DatabaseHelper.instance.getExpenses();
    final incomeData = await DatabaseHelper.instance.getIncomes();
    final installmentData = await DatabaseHelper.instance.getInstallments();
    final investmentData = await DatabaseHelper.instance.getInvestments();

    if (!mounted) return;

    await SharedBudgetService.updateRealtimeSubscription(() {
      if (mounted) loadAll();
    });

    setState(() {
      expenses = expenseData.map((item) => Expense.fromMap(item)).toList();
      incomes = incomeData.map((item) => Income.fromMap(item)).toList();
      installments = installmentData
          .map((item) => Installment.fromMap(item))
          .toList();
      investments = investmentData
          .map((item) => Investment.fromMap(item))
          .toList();
      isLoading = false;
    });

    if (!_startupRatesChecked && investments.isNotEmpty) {
      _startupRatesChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateInvestmentRatesOncePerDay();
      });
    }
  }

  Future<void> _updateInvestmentRatesOncePerDay() async {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final lastUpdated = await DatabaseHelper.instance.getAppSetting(
      'tcmb_rates_last_updated',
    );
    if (lastUpdated == today || investments.isEmpty) return;

    try {
      final rates = await TcmbRatesService.fetchBuyingRates();
      for (final investment in investments) {
        final rate = switch (investment.type) {
          'Dolar' => rates['USD'],
          'Euro' => rates['EUR'],
          _ => null,
        };
        if (rate == null || investment.id == null) continue;
        await DatabaseHelper.instance.updateInvestment(
          investment.id!,
          investment.copyWith(currentPrice: rate).toMap(),
        );
      }

      await DatabaseHelper.instance.setAppSetting(
        'tcmb_rates_last_updated',
        today,
      );
      await loadAll();
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Güncel kurlar alınamadı'),
          content: const Text(
            'İnternet bağlantısı yok veya TCMB’ye ulaşılamadı. '
            'Dolar ve euro için önceki fiyatlar korunuyor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
      );
    });
  }

  // ==========================================================
  // GİDER İŞLEMLERİ
  // ==========================================================

  Future<void> addExpense() async {
    final result = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(builder: (context) => const AddExpensePage()),
    );

    if (result == null) return;

    await DatabaseHelper.instance.insertExpense(result.toMap());
    await loadAll();
  }

  Future<void> editExpense(Expense expense) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpensePage(
          expense: expense,
          onSave: (updatedExpense) async {
            final updatedRows = await DatabaseHelper.instance.updateExpense(
              expense.id!,
              updatedExpense.toMap(),
            );
            if (updatedRows == 0) {
              throw StateError('Gider kaydı bulunamadı.');
            }
            await loadAll();
          },
        ),
      ),
    );
  }

  Future<void> deleteExpense(Expense expense) async {
    if (expense.id == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Harcamayı Sil'),
          content: Text(
            '${expense.amount.toStringAsFixed(2)} ₺ '
            'tutarındaki ${expense.category} '
            'harcamasını silmek istiyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await DatabaseHelper.instance.deleteExpense(expense.id!);
    await loadAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Harcama silindi.')));
  }

  // ==========================================================
  // GELİR İŞLEMLERİ
  // ==========================================================

  Future<void> addIncome() async {
    final result = await Navigator.push<Income>(
      context,
      MaterialPageRoute(builder: (context) => const AddIncomePage()),
    );

    if (result == null) return;

    await DatabaseHelper.instance.insertIncome(result.toMap());
    await loadAll();
  }

  Future<void> editIncome(Income income) async {
    final result = await Navigator.push<Income>(
      context,
      MaterialPageRoute(builder: (context) => AddIncomePage(income: income)),
    );

    if (result == null || income.id == null) return;

    await DatabaseHelper.instance.updateIncome(income.id!, result.toMap());
    await loadAll();
  }

  Future<void> deleteIncome(Income income) async {
    if (income.id == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Geliri Sil'),
          content: Text(
            '${income.amount.toStringAsFixed(2)} ₺ '
            'tutarındaki ${income.source} '
            'gelirini silmek istiyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await DatabaseHelper.instance.deleteIncome(income.id!);
    await loadAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Gelir silindi.')));
  }

  // ==========================================================
  // TAKSİT İŞLEMLERİ
  // ==========================================================

  Future<void> addInstallment() async {
    final result = await Navigator.push<Installment>(
      context,
      MaterialPageRoute(builder: (context) => const AddInstallmentPage()),
    );

    if (result == null) return;

    await DatabaseHelper.instance.insertInstallment(result.toMap());
    await loadAll();
  }

  Future<void> editInstallment(Installment installment) async {
    final result = await Navigator.push<Installment>(
      context,
      MaterialPageRoute(
        builder: (context) => AddInstallmentPage(installment: installment),
      ),
    );

    if (result == null || installment.id == null) return;

    await DatabaseHelper.instance.updateInstallment(
      installment.id!,
      result.toMap(),
    );
    await loadAll();
  }

  Future<void> deleteInstallment(Installment installment) async {
    if (installment.id == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Taksiti Sil'),
          content: Text('${installment.title} taksitini silmek istiyor musun?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await DatabaseHelper.instance.deleteInstallment(installment.id!);
    await loadAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Taksit silindi.')));
  }

  // Bir taksidin bu ayki ödemesini yapar: paidMonths'u 1 artırır
  // ve otomatik olarak "Taksit" kategorisinde bir gider kaydı oluşturur.
  Future<void> payInstallmentMonth(Installment installment) async {
    if (installment.id == null || installment.isCompleted) return;

    final updated = installment.copyWith(
      paidMonths: installment.paidMonths + 1,
    );

    await DatabaseHelper.instance.updateInstallment(
      installment.id!,
      updated.toMap(),
    );

    final expense = Expense(
      category: 'Taksit',
      description:
          '${installment.title} (${updated.paidMonths}/${installment.totalMonths})',
      amount: installment.monthlyAmount,
      date: DateTime.now().toIso8601String(),
      icon: Expense.iconForCategory('Taksit'),
    );

    await DatabaseHelper.instance.insertExpense(expense.toMap());

    await loadAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${installment.title} için bu ayın taksiti ödendi.'),
      ),
    );
  }

  // ==========================================================
  // YATIRIM İŞLEMLERİ
  // ==========================================================

  Future<void> addInvestment() async {
    final result = await Navigator.push<Investment>(
      context,
      MaterialPageRoute(builder: (context) => const AddInvestmentPage()),
    );

    if (result == null) return;

    await DatabaseHelper.instance.insertInvestment(result.toMap());
    await loadAll();
  }

  Future<void> editInvestment(Investment investment) async {
    final result = await Navigator.push<Investment>(
      context,
      MaterialPageRoute(
        builder: (context) => AddInvestmentPage(investment: investment),
      ),
    );

    if (result == null || investment.id == null) return;

    await DatabaseHelper.instance.updateInvestment(
      investment.id!,
      result.toMap(),
    );
    await loadAll();
  }

  Future<void> deleteInvestment(Investment investment) async {
    if (investment.id == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yatırımı Sil'),
          content: Text(
            '${investment.quantity} ${unitForInvestmentType(investment.type)} '
            '${investment.type} yatırımını silmek istiyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await DatabaseHelper.instance.deleteInvestment(investment.id!);
    await loadAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Yatırım silindi.')));
  }

  Future<void> updateInvestmentPrice(Investment investment) async {
    final controller = TextEditingController(
      text: investment.currentPrice.toString(),
    );

    final newPrice = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${investment.type} - Güncel Fiyat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  'Güncel birim fiyat (₺/${unitForInvestmentType(investment.type)})',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );
                Navigator.pop(context, value);
              },
              child: const Text('Güncelle'),
            ),
          ],
        );
      },
    );

    if (newPrice == null || newPrice <= 0 || investment.id == null) return;

    final updated = investment.copyWith(currentPrice: newPrice);
    await DatabaseHelper.instance.updateInvestment(
      investment.id!,
      updated.toMap(),
    );
    await loadAll();
  }

  // ==========================================================
  // EKLEME MENÜSÜ
  // ==========================================================

  void showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.arrow_downward, color: Colors.green),
                title: const Text('Gelir Ekle'),
                onTap: () {
                  Navigator.pop(context);
                  addIncome();
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward, color: Colors.red),
                title: const Text('Gider Ekle'),
                onTap: () {
                  Navigator.pop(context);
                  addExpense();
                },
              ),
              ListTile(
                leading: const Icon(Icons.credit_card, color: Colors.blue),
                title: const Text('Taksit Ekle'),
                onTap: () {
                  Navigator.pop(context);
                  addInstallment();
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.amber),
                title: const Text('Yatırım Ekle'),
                onTap: () {
                  Navigator.pop(context);
                  addInvestment();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void showExpenseMenu(Expense expense) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Düzenle'),
                onTap: () {
                  Navigator.pop(context);
                  editExpense(expense);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  deleteExpense(expense);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void showIncomeMenu(Income income) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Düzenle'),
                onTap: () {
                  Navigator.pop(context);
                  editIncome(income);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  deleteIncome(income);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void showInstallmentMenu(Installment installment) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!installment.isCompleted)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Bu Ayı Öde'),
                  onTap: () {
                    Navigator.pop(context);
                    payInstallmentMonth(installment);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Düzenle'),
                onTap: () {
                  Navigator.pop(context);
                  editInstallment(installment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  deleteInstallment(installment);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void showInvestmentMenu(Investment investment) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.price_change, color: Colors.blue),
                title: const Text('Güncel Fiyatı Güncelle'),
                onTap: () {
                  Navigator.pop(context);
                  updateInvestmentPrice(investment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Düzenle'),
                onTap: () {
                  Navigator.pop(context);
                  editInvestment(investment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  deleteInvestment(investment);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // ANA EKRAN
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Açıcı Budget')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: currentTab,
              children: [
                buildOverviewTab(),
                buildInstallmentsTab(),
                buildInvestmentsTab(),
                SharedBudgetPage(
                  initialInviteCode: widget.inviteCode,
                  onSharedBudgetChanged: loadAll,
                  onBack: () => setState(() => currentTab = 0),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (index) {
          setState(() => currentTab = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Ana Sayfa'),
          NavigationDestination(
            icon: Icon(Icons.credit_card),
            label: 'Taksitler',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up),
            label: 'Yatırımlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups),
            label: 'Ortak',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddMenu,
        icon: const Icon(Icons.add),
        label: const Text('Ekle'),
      ),
    );
  }

  // ==========================================================
  // TAB 1: ANA SAYFA / ÖZET
  // ==========================================================

  Widget buildOverviewTab() {
    // Gelir + gider işlemlerini tarihe göre tek listede birleştir
    final items = <_TransactionItem>[
      ...expensesForMonth.map(
        (e) => _TransactionItem(
          title: e.category,
          subtitle: e.description,
          amount: -e.amount,
          date: e.date,
          icon: e.icon,
          color: Colors.red,
          onTap: () => showExpenseMenu(e),
        ),
      ),
      ...incomesForMonth.map(
        (i) => _TransactionItem(
          title: i.source,
          subtitle: i.description,
          amount: i.amount,
          date: i.date,
          icon: Icons.attach_money,
          color: Colors.green,
          onTap: () => showIncomeMenu(i),
        ),
      ),
      if (carryoverIncome > 0)
        _TransactionItem(
          title: 'Geçen aydan devir',
          subtitle: 'Önceki aylardan kalan bakiye',
          amount: carryoverIncome,
          date:
              '${selectedMonth.year.toString().padLeft(4, '0')}-'
              '${selectedMonth.month.toString().padLeft(2, '0')}-01',
          icon: Icons.call_received,
          color: Colors.green,
          onTap: () {},
        ),
      if (carryoverDeficit > 0)
        _TransactionItem(
          title: 'Geçen aydan devreden açık',
          subtitle: 'Önceki aylardan kalan eksi bakiye',
          amount: -carryoverDeficit,
          date:
              '${selectedMonth.year.toString().padLeft(4, '0')}-'
              '${selectedMonth.month.toString().padLeft(2, '0')}-01',
          icon: Icons.call_received,
          color: Colors.red,
          onTap: () {},
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scrollbar(
      controller: overviewScrollController,
      thumbVisibility: true,
      interactive: true,
      child: RefreshIndicator(
        onRefresh: loadAll,
        child: ListView(
          controller: overviewScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          // Son işlem kartı, alttaki Ekle düğmesinin arkasında kalmasın.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // ==================================================
            // AY SEÇİCİ
            // ==================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => changeMonth(-1),
                ),
                Text(
                  formatMonth(selectedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => changeMonth(1),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ==================================================
            // BAKİYE
            // ==================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bu Ayki Bakiye',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${balance.toStringAsFixed(2)} ₺',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gelir',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${totalIncome.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                color: Colors.greenAccent.shade100,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gider',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${totalExpense.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                color: Colors.red.shade100,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (activeInstallments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${activeInstallments.length} aktif taksit'),
                          Text(
                            'Aylık toplam: ${pendingInstallmentTotal.toStringAsFixed(2)} ₺',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ==================================================
            // İŞLEMLER
            // ==================================================
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bu Ayki İşlemler',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Bu ay için henüz işlem yok.'),
              ),

            ...items.map((item) {
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(item.icon)),
                  title: Text(item.title),
                  subtitle: Text(
                    item.subtitle.isEmpty
                        ? formatDate(item.date)
                        : '${item.subtitle} • ${formatDate(item.date)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.amount >= 0 ? '+' : ''}'
                        '${item.amount.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          color: item.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: item.onTap,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TAB 2: TAKSİTLER
  // ==========================================================

  Widget buildInstallmentsTab() {
    return Scrollbar(
      controller: installmentsScrollController,
      thumbVisibility: true,
      interactive: true,
      child: RefreshIndicator(
        onRefresh: loadAll,
        child: SingleChildScrollView(
          controller: installmentsScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Taksitler',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (installments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Henüz taksit eklenmedi.'),
                ),
              ...installments.map((installment) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    installment.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(installment.category),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => showInstallmentMenu(installment),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: installment.progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            color: installment.isCompleted
                                ? Colors.green
                                : Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${installment.paidMonths}/${installment.totalMonths} ay ödendi',
                            ),
                            Text(
                              'Aylık: ${installment.monthlyAmount.toStringAsFixed(2)} ₺',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          installment.isCompleted
                              ? 'Taksit tamamlandı ✓'
                              : 'Kalan: ${installment.remainingAmount.toStringAsFixed(2)} ₺'
                                    ' (${installment.remainingMonths} ay)',
                          style: TextStyle(
                            color: installment.isCompleted
                                ? Colors.green
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (!installment.isCompleted) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => payInstallmentMonth(installment),
                              icon: const Icon(Icons.check),
                              label: const Text('Bu Ayı Öde'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // TAB 3: YATIRIMLAR
  // ==========================================================

  Widget buildInvestmentsTab() {
    return Scrollbar(
      controller: investmentsScrollController,
      thumbVisibility: true,
      interactive: true,
      child: RefreshIndicator(
        onRefresh: loadAll,
        child: SingleChildScrollView(
          controller: investmentsScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yatırımlarım',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (investments.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade800,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toplam Yatırım Değeri',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${totalInvestmentValue.toStringAsFixed(2)} ₺',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${totalInvestmentProfitLoss >= 0 ? '+' : ''}'
                        '${totalInvestmentProfitLoss.toStringAsFixed(2)} ₺ '
                        'kar/zarar',
                        style: TextStyle(
                          color: totalInvestmentProfitLoss >= 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              if (investments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Henüz yatırım eklenmedi. Altın, döviz veya gümüş ekleyebilirsin.',
                  ),
                ),

              ...investments.map((investment) {
                final isProfit = investment.profitLoss >= 0;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: colorForInvestmentType(
                                investment.type,
                              ).withValues(alpha: 0.15),
                              child: Icon(
                                iconForInvestmentType(investment.type),
                                color: colorForInvestmentType(investment.type),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    investment.type,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${investment.quantity} ${unitForInvestmentType(investment.type)} • '
                                    'Alış: ${investment.purchasePrice.toStringAsFixed(2)} ₺',
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => showInvestmentMenu(investment),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Güncel Değer',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '${investment.currentValue.toStringAsFixed(2)} ₺',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Kar/Zarar',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '${isProfit ? '+' : ''}'
                                  '${investment.profitLoss.toStringAsFixed(2)} ₺ '
                                  '(${investment.profitLossPercent.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    color: isProfit ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => updateInvestmentPrice(investment),
                            icon: const Icon(Icons.price_change),
                            label: const Text('Güncel Fiyatı Gir'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionItem {
  final String title;
  final String subtitle;
  final double amount;
  final String date;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _TransactionItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

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
      text: widget.expense?.amount.toString() ?? '',
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
    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));

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
      text: widget.income?.amount.toString() ?? '',
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
    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));

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

// ============================================================
// TAKSİT EKLE / DÜZENLE
// ============================================================

class AddInstallmentPage extends StatefulWidget {
  final Installment? installment;

  const AddInstallmentPage({super.key, this.installment});

  @override
  State<AddInstallmentPage> createState() => _AddInstallmentPageState();
}

class _AddInstallmentPageState extends State<AddInstallmentPage> {
  late final TextEditingController titleController;
  late final TextEditingController totalAmountController;
  late final TextEditingController totalMonthsController;
  late final TextEditingController paidMonthsController;

  String selectedCategory = 'Diğer';
  late DateTime startDate;

  bool get isEditing => widget.installment != null;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.installment?.title ?? '',
    );
    totalAmountController = TextEditingController(
      text: widget.installment?.totalAmount.toString() ?? '',
    );
    totalMonthsController = TextEditingController(
      text: widget.installment?.totalMonths.toString() ?? '',
    );
    paidMonthsController = TextEditingController(
      text: widget.installment?.paidMonths.toString() ?? '0',
    );

    selectedCategory = widget.installment?.category ?? 'Diğer';

    startDate = widget.installment != null
        ? (DateTime.tryParse(widget.installment!.startDate) ?? DateTime.now())
        : DateTime.now();
  }

  Future<void> pickStartDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result != null) {
      setState(() => startDate = result);
    }
  }

  void saveInstallment() {
    final title = titleController.text.trim();
    final totalAmount = double.tryParse(
      totalAmountController.text.replaceAll(',', '.'),
    );
    final totalMonths = int.tryParse(totalMonthsController.text);
    final paidMonths = int.tryParse(paidMonthsController.text) ?? 0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir taksit adı girin.')),
      );
      return;
    }

    if (totalAmount == null || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir toplam tutar girin.')),
      );
      return;
    }

    if (totalMonths == null || totalMonths <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir taksit sayısı girin.'),
        ),
      );
      return;
    }

    if (paidMonths < 0 || paidMonths > totalMonths) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödenen taksit sayısı geçersiz.')),
      );
      return;
    }

    final installment = Installment(
      id: widget.installment?.id,
      title: title,
      category: selectedCategory,
      totalAmount: totalAmount,
      totalMonths: totalMonths,
      paidMonths: paidMonths,
      startDate: startDate.toIso8601String(),
    );

    Navigator.pop(context, installment);
  }

  @override
  void dispose() {
    titleController.dispose();
    totalAmountController.dispose();
    totalMonthsController.dispose();
    paidMonthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Taksiti Düzenle' : 'Taksit Ekle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Taksit Adı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Örn: Telefon, Beyaz Eşya',
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
              'Toplam Tutar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: totalAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Örn: 12000',
                suffixText: '₺',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Taksit Sayısı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: totalMonthsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Örn: 12',
                suffixText: 'ay',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Şu Ana Kadar Ödenen Taksit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: paidMonthsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Örn: 0',
                suffixText: 'ay',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Başlangıç Tarihi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: pickStartDate,
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                child: Text(formatDate(startDate.toIso8601String())),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: saveInstallment,
                child: Text(
                  isEditing ? 'Değişiklikleri Kaydet' : 'Taksiti Kaydet',
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
      text: widget.investment?.quantity.toString() ?? '',
    );
    purchasePriceController = TextEditingController(
      text: widget.investment?.purchasePrice.toString() ?? '',
    );
    currentPriceController = TextEditingController(
      text:
          widget.investment?.currentPrice.toString() ??
          widget.investment?.purchasePrice.toString() ??
          '',
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
    final quantity = double.tryParse(
      quantityController.text.replaceAll(',', '.'),
    );
    final purchasePrice = double.tryParse(
      purchasePriceController.text.replaceAll(',', '.'),
    );
    final currentPriceText = currentPriceController.text.trim();
    final currentPrice = currentPriceText.isEmpty
        ? purchasePrice
        : double.tryParse(currentPriceText.replaceAll(',', '.'));

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
