import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/budget_calculator.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/installment.dart';
import '../models/investment.dart';
import '../services/crash_reporting.dart';
import '../services/database_helper.dart';
import '../services/shared_budget_service.dart';
import '../services/tcmb_rates_service.dart';
import '../utils/constants.dart';
import '../utils/formatting.dart';
import 'add_expense_page.dart';
import 'add_income_page.dart';
import 'add_installment_page.dart';
import 'add_investment_page.dart';
import 'installments_tab.dart';
import 'investments_tab.dart';
import 'overview_tab.dart';
import 'settings_page.dart';
import 'shared_budget_page.dart';

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

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  int currentTab = 0;

  bool isLoading = true;
  String? _loadError;
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

  // Ortak bütçede internet yokken yapılan değişiklikleri bağlantı gelince
  // göndermek için düzenli aralıklarla tekrar dener.
  Timer? _sharedSyncTimer;

  @override
  void initState() {
    super.initState();
    currentTab = widget.initialTab;
    WidgetsBinding.instance.addObserver(this);
    _sharedSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (SharedBudgetService.hasActiveSharedBudget &&
          (SharedBudgetService.isOffline ||
              SharedBudgetService.pendingChangeCount > 0)) {
        loadAll();
      }
    });
    loadAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        SharedBudgetService.hasActiveSharedBudget) {
      loadAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sharedSyncTimer?.cancel();
    overviewScrollController.dispose();
    installmentsScrollController.dispose();
    investmentsScrollController.dispose();
    super.dispose();
  }

  // ==========================================================
  // TÜM VERİYİ YÜKLE
  // ==========================================================

  Future<void> loadAll() async {
    try {
      final data = await Future.wait<List<Map<String, dynamic>>>([
        DatabaseHelper.instance.getExpenses(),
        DatabaseHelper.instance.getIncomes(),
        DatabaseHelper.instance.getInstallments(),
        DatabaseHelper.instance.getInvestments(),
      ]).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      await SharedBudgetService.updateRealtimeSubscription(() {
        if (mounted) loadAll();
      });

      setState(() {
        expenses = data[0].map((item) => Expense.fromMap(item)).toList();
        incomes = data[1].map((item) => Income.fromMap(item)).toList();
        installments = data[2]
            .map((item) => Installment.fromMap(item))
            .toList();
        investments = data[3].map((item) => Investment.fromMap(item)).toList();
        isLoading = false;
        _loadError = null;
      });

      if (mounted && SharedBudgetService.rejectedChangeCount > 0) {
        final count = SharedBudgetService.rejectedChangeCount;
        SharedBudgetService.rejectedChangeCount = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'İnternetsizken yapılan $count değişiklik ortak bütçeye '
              'işlenemedi. Kayıt diğer kişi tarafından silinmiş olabilir.',
            ),
          ),
        );
      }

      if (!_startupRatesChecked && investments.isNotEmpty) {
        _startupRatesChecked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateInvestmentRatesOncePerDay();
        });
      }
    } catch (error, stackTrace) {
      CrashReporting.report(error, stackTrace);
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _loadError = SharedBudgetService.hasActiveSharedBudget
            ? 'Ortak bütçe verileri yüklenemedi. İnternet bağlantısını kontrol edip tekrar deneyin.'
            : 'Veriler yüklenemedi. Tekrar deneyin.';
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
      MaterialPageRoute(
        builder: (context) => AddExpensePage(
          onSave: (expense) async {
            await DatabaseHelper.instance.insertExpense(expense.toMap());
          },
        ),
      ),
    );

    if (result == null) return;

    final expenseDate = DateTime.tryParse(result.date);
    if (expenseDate != null && mounted) {
      setState(() {
        selectedMonth = DateTime(expenseDate.year, expenseDate.month);
        currentTab = 0;
      });
    }
    try {
      await loadAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harcama kaydedildi ancak liste yenilenemedi. Aşağı çekerek yenileyin.',
          ),
        ),
      );
    }
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
            '${formatMoney(expense.amount)} '
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
            '${formatMoney(income.amount)} '
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
            '${formatQuantity(investment.quantity)} ${unitForInvestmentType(investment.type)} '
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
      text: formatForInput(investment.currentPrice),
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
                final value = parseAmount(controller.text);
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
      appBar: AppBar(
        title: const Text('Açıcı Budget'),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SettingsPage(onDataChanged: loadAll),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_loadError == null &&
                    SharedBudgetService.hasActiveSharedBudget &&
                    (SharedBudgetService.isOffline ||
                        SharedBudgetService.pendingChangeCount > 0))
                  MaterialBanner(
                    leading: const Icon(Icons.cloud_off),
                    content: Text(
                      SharedBudgetService.pendingChangeCount > 0
                          ? 'İnternet bağlantısı yok. '
                                '${SharedBudgetService.pendingChangeCount} '
                                'değişiklik telefonda bekliyor, bağlantı '
                                'gelince ortak bütçeye gönderilecek.'
                          : 'İnternet bağlantısı yok. Ortak bütçenin son '
                                'görülen hâli gösteriliyor.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: loadAll,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                if (_loadError != null)
                  MaterialBanner(
                    content: Text(_loadError!),
                    actions: [
                      TextButton(
                        onPressed: loadAll,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                Expanded(
                  child: IndexedStack(
                    index: currentTab,
                    children: [
                      OverviewTab(
                        summary: MonthSummary.calculate(
                          expenses: expenses,
                          incomes: incomes,
                          month: selectedMonth,
                        ),
                        activeInstallmentCount: activeInstallments(installments)
                            .length,
                        monthlyInstallmentTotal: monthlyInstallmentTotal(
                          installments,
                        ),
                        scrollController: overviewScrollController,
                        onRefresh: loadAll,
                        onChangeMonth: changeMonth,
                        onExpenseTap: showExpenseMenu,
                        onIncomeTap: showIncomeMenu,
                      ),
                      InstallmentsTab(
                        installments: installments,
                        scrollController: installmentsScrollController,
                        onRefresh: loadAll,
                        onInstallmentTap: showInstallmentMenu,
                        onPayMonth: payInstallmentMonth,
                      ),
                      InvestmentsTab(
                        investments: investments,
                        scrollController: investmentsScrollController,
                        onRefresh: loadAll,
                        onInvestmentTap: showInvestmentMenu,
                        onUpdatePrice: updateInvestmentPrice,
                      ),
                      SharedBudgetPage(
                        initialInviteCode: widget.inviteCode,
                        onSharedBudgetChanged: loadAll,
                        onBack: () => setState(() => currentTab = 0),
                      ),
                    ],
                  ),
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
          NavigationDestination(icon: Icon(Icons.groups), label: 'Ortak'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddMenu,
        icon: const Icon(Icons.add),
        label: const Text('Ekle'),
      ),
    );
  }
}
