import 'dart:async';

import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'database/isar_service.dart';
import 'models/app_settings.dart';
import 'models/category.dart';
import 'models/provisional_transaction.dart';
import 'models/transaction.dart';
import 'navigation/app_route.dart';
import 'screens/categories/add_edit_category_screen.dart';
import 'screens/categories/categories_screen.dart';
import 'screens/debt_loan/debt_loan_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/export_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/transactions/add_edit_transaction_screen.dart';
import 'screens/transactions/provisional_transactions_screen.dart';
import 'screens/transactions/transactions_screen.dart';
import 'services/provisional_notification_service.dart';
import 'services/provisional_transaction_repository.dart';
import 'services/settings_service.dart';
import 'services/sms_transaction_service.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';

class ExpenseTrackerBootstrap extends StatefulWidget {
  const ExpenseTrackerBootstrap({super.key});

  @override
  State<ExpenseTrackerBootstrap> createState() =>
      _ExpenseTrackerBootstrapState();
}

class _ExpenseTrackerBootstrapState extends State<ExpenseTrackerBootstrap> {
  final SettingsService _settingsService = SettingsService();
  bool _ready = false;
  AppSettingsModel? _settings;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await IsarService.instance.initialize();
    final settings = await _settingsService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _ready = true;
    });
  }

  Future<void> _reloadSettings() async {
    final settings = await _settingsService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings ?? AppSettingsModel.defaults();
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeModeValue,
      home: _ready
          ? AppShell(settings: settings, onSettingsChanged: _reloadSettings)
          : const SplashScreen(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettingsModel settings;
  final Future<void> Function() onSettingsChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final SmsTransactionService _smsTransactionService = SmsTransactionService();
  final ProvisionalTransactionRepository _provisionalRepository =
      ProvisionalTransactionRepository();
  final ProvisionalNotificationService _notificationService =
      ProvisionalNotificationService();
  int _selectedIndex = 0;
  int _reloadToken = 0;
  int _provisionalCount = 0;
  bool _showNotificationSplash = false;
  bool _handlingNotificationLaunch = false;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  StreamSubscription<ParsedSmsTransaction>? _smsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncProvisionalCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationLaunch();
      _syncSmsImportWithSettings();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleNotificationLaunch();
    }
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.smsImportEnabled !=
        widget.settings.smsImportEnabled) {
      _syncSmsImportWithSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _smsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startSmsImport() async {
    if (_smsSubscription != null) {
      return;
    }
    var granted = await _smsTransactionService.hasSmsPermission();
    if (!granted) {
      return;
    }
    _smsSubscription = _smsTransactionService.parsedTransactions.listen(
      _saveProvisionalTransaction,
    );
  }

  Future<void> _stopSmsImport() async {
    await _smsSubscription?.cancel();
    _smsSubscription = null;
    await _syncProvisionalCount();
  }

  Future<void> _syncSmsImportWithSettings() async {
    if (widget.settings.smsImportEnabled) {
      await _startSmsImport();
      await _syncProvisionalCount();
      return;
    }
    await _stopSmsImport();
  }

  Future<void> _openTransactionForm({
    TransactionModel? transaction,
    String? forcedDebtLoanKind,
    TransactionModel? parentTransaction,
    SmsTransactionDraft? initialDraft,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) => AddEditTransactionScreen(
          transaction: transaction,
          forcedDebtLoanKind: forcedDebtLoanKind,
          parentTransaction: parentTransaction,
          initialDraft: initialDraft,
          settings: widget.settings,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(() {
        _reloadToken++;
      });
    }
  }

  Future<void> _saveProvisionalTransaction(ParsedSmsTransaction parsed) async {
    final provisional = ProvisionalTransaction()
      ..amountMinor = parsed.amountMinor
      ..transactionType = parsed.transactionType
      ..note = parsed.note
      ..smsBody = parsed.smsBody
      ..sender = parsed.sender
      ..paymentMethod = parsed.paymentMethod
      ..sourceKey = parsed.sourceKey
      ..smsReceivedAt = parsed.smsReceivedAt
      ..createdAt = DateTime.now()
      ..status = ProvisionalTransactionStatus.pending;
    await _provisionalRepository.saveIfNew(provisional);
    await _syncProvisionalCount();
  }

  Future<void> _syncProvisionalCount() async {
    final count = await _provisionalRepository.pendingCount();
    await _notificationService.syncPendingCount(count);
    if (!mounted) {
      return;
    }
    setState(() {
      _provisionalCount = count;
      _reloadToken++;
    });
  }

  Future<void> _handleNotificationLaunch() async {
    if (_handlingNotificationLaunch) {
      return;
    }
    _handlingNotificationLaunch = true;
    final shouldOpen = await _notificationService.consumeLaunchRequest();
    if (!shouldOpen || !mounted) {
      _handlingNotificationLaunch = false;
      return;
    }
    setState(() => _showNotificationSplash = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      _handlingNotificationLaunch = false;
      return;
    }
    setState(() => _showNotificationSplash = false);
    await _openProvisionalTransactionsScreen();
    _handlingNotificationLaunch = false;
  }

  Future<void> _openProvisionalTransactionsScreen() async {
    await Navigator.of(context).push<void>(
      AppRoute(
        builder: (_) => ProvisionalTransactionsScreen(
          settings: widget.settings,
          onChanged: _syncProvisionalCount,
        ),
      ),
    );
    await _syncProvisionalCount();
  }

  Future<void> _openCategoryForm({CategoryModel? category}) async {
    final changed = await Navigator.of(context).push<bool>(
      AppRoute(builder: (_) => AddEditCategoryScreen(category: category)),
    );
    if (changed == true && mounted) {
      setState(() {
        _reloadToken++;
      });
    }
  }

  Future<void> _openDebtLoanScreen() async {
    final changed = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) => DebtLoanScreen(
          reloadToken: _reloadToken,
          settings: widget.settings,
          onEditTransaction: (transaction) =>
              _openTransactionForm(transaction: transaction),
          onAddPayback: (kind, parentTransaction) => _openTransactionForm(
            forcedDebtLoanKind: kind,
            parentTransaction: parentTransaction,
          ),
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(() {
        _reloadToken++;
      });
    }
  }

  Future<void> _openExportScreen() async {
    await Navigator.of(
      context,
    ).push<void>(AppRoute(builder: (_) => const ExportScreen()));
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return HomeScreen(
          reloadToken: _reloadToken,
          settings: widget.settings,
          onOpenMonth: (month) {
            setState(() {
              _selectedMonth = month;
              _selectedIndex = 1;
              _reloadToken++;
            });
          },
          onOpenDebtLoan: _openDebtLoanScreen,
          onOpenProvisionalTransactions: _openProvisionalTransactionsScreen,
          onEditTransaction: (transaction) =>
              _openTransactionForm(transaction: transaction),
          provisionalCount: _provisionalCount,
        );
      case 1:
        return TransactionsScreen(
          reloadToken: _reloadToken,
          settings: widget.settings,
          initialMonth: _selectedMonth,
          onEditTransaction: (transaction) =>
              _openTransactionForm(transaction: transaction),
        );
      case 2:
        return CategoriesScreen(
          reloadToken: _reloadToken,
          onAddCategory: () => _openCategoryForm(),
          onEditCategory: (category) => _openCategoryForm(category: category),
        );
      case 3:
        return SettingsScreen(
          settings: widget.settings,
          onOpenDebtLoan: _openDebtLoanScreen,
          onOpenExport: _openExportScreen,
          onOpenProvisionalTransactions: _openProvisionalTransactionsScreen,
          onSettingsChanged: () async {
            await widget.onSettingsChanged();
            if (mounted) {
              setState(() {
                _reloadToken++;
              });
            }
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: _buildBody(),
            ),
          ),
          bottomNavigationBar: BottomNav(
            selectedIndex: _selectedIndex,
            onChanged: (index) {
              setState(() {
                _selectedIndex = index;
                _reloadToken++;
              });
            },
            onAddPressed: () => _openTransactionForm(),
          ),
        ),
        if (_showNotificationSplash)
          const Positioned.fill(child: SplashScreen()),
      ],
    );
  }
}
