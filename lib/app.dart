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
import 'screens/lock/app_lock_screen.dart';
import 'screens/settings/export_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/sms_compatibility_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/spendings/spendings_screen.dart';
import 'screens/transactions/add_edit_transaction_screen.dart';
import 'screens/transactions/provisional_transactions_screen.dart';
import 'screens/transactions/transactions_screen.dart';
import 'services/app_lock_service.dart';
import 'services/provisional_notification_service.dart';
import 'services/provisional_transaction_repository.dart';
import 'services/category_service.dart';
import 'services/settings_service.dart';
import 'services/sms_transaction_service.dart';
import 'services/transaction_service.dart';
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
          ? AppLockGate(
              settings: settings,
              child: AppShell(
                settings: settings,
                onSettingsChanged: _reloadSettings,
              ),
            )
          : const SplashScreen(),
    );
  }
}

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.settings, required this.child});

  final AppSettingsModel settings;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final AppLockService _appLockService = AppLockService();
  late bool _unlocked;
  late bool _showPrivacyCover;
  bool _isResumed = true;
  bool _skipNextResumeLock = false;
  bool _secureWindowEnabled = false;
  DateTime? _backgroundedAt;

  static const _secureWindowAlwaysOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unlocked = !widget.settings.appLockEnabled;
    _showPrivacyCover = widget.settings.appLockEnabled;
    _syncSecureWindow();
  }

  @override
  void didUpdateWidget(covariant AppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.settings.appLockEnabled) {
      _unlocked = true;
      _showPrivacyCover = false;
      _backgroundedAt = null;
      _syncSecureWindow();
      return;
    }
    if (!oldWidget.settings.appLockEnabled && widget.settings.appLockEnabled) {
      _unlocked = true;
      _showPrivacyCover = false;
    }
    _syncSecureWindow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.settings.appLockEnabled) {
      _hidePrivacyCover();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _isResumed = true;
      if (_skipNextResumeLock) {
        _skipNextResumeLock = false;
        _syncSecureWindow();
        return;
      }
      if (_shouldLockOnResume()) {
        _lockAndCover();
      } else {
        _hidePrivacyCover();
      }
      _backgroundedAt = null;
      return;
    }
    _isResumed = false;
    if (!_unlocked) {
      _showPrivacyCoverForSnapshot();
      return;
    }
    if (_unlocked &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      _backgroundedAt ??= DateTime.now();
      _showPrivacyCoverForSnapshot();
      if (widget.settings.appLockTimeout == Duration.zero && mounted) {
        setState(() => _unlocked = false);
      }
      _syncSecureWindow();
    }
  }

  bool _shouldLockOnResume() {
    if (!_unlocked) {
      return true;
    }
    final timeout = widget.settings.appLockTimeout;
    if (timeout == Duration.zero) {
      return true;
    }
    final backgroundedAt = _backgroundedAt;
    if (backgroundedAt == null) {
      return false;
    }
    return DateTime.now().difference(backgroundedAt) >= timeout;
  }

  void _showPrivacyCoverForSnapshot() {
    if (mounted && !_showPrivacyCover) {
      setState(() => _showPrivacyCover = true);
    }
    _syncSecureWindow();
  }

  void _hidePrivacyCover() {
    if (mounted && _showPrivacyCover && _unlocked) {
      setState(() => _showPrivacyCover = false);
    }
    _syncSecureWindow();
  }

  void _lockAndCover() {
    if (mounted) {
      setState(() {
        _unlocked = false;
        _showPrivacyCover = true;
      });
    }
    _syncSecureWindow();
  }

  void _syncSecureWindow() {
    final enabled =
        _secureWindowAlwaysOn ||
        (widget.settings.appLockEnabled && !_unlocked && _isResumed);
    if (enabled == _secureWindowEnabled) {
      return;
    }
    _secureWindowEnabled = enabled;
    _appLockService.setSecureWindow(enabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_secureWindowEnabled && !_secureWindowAlwaysOn) {
      _appLockService.setSecureWindow(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showPrivacyCover) const Positioned.fill(child: _PrivacyCover()),
        if (widget.settings.appLockEnabled && !_unlocked && _isResumed)
          Positioned.fill(
            child: AppLockScreen(
              settings: widget.settings,
              onSystemUnlockStarted: () => _skipNextResumeLock = true,
              onUnlocked: () {
                setState(() {
                  _backgroundedAt = null;
                  _unlocked = true;
                  _showPrivacyCover = false;
                });
                _syncSecureWindow();
              },
            ),
          ),
      ],
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
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
  final CategoryService _categoryService = CategoryService();
  final TransactionService _transactionService = TransactionService();
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
      _saveSmsTransaction,
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

  Future<void> _saveSmsTransaction(ParsedSmsTransaction parsed) async {
    if (widget.settings.smsImportModeValue ==
        SettingValues.smsImportMainTransaction) {
      await _saveMainSmsTransaction(parsed);
      return;
    }
    await _saveProvisionalTransaction(parsed);
  }

  Future<void> _saveMainSmsTransaction(ParsedSmsTransaction parsed) async {
    final isIncome = parsed.transactionType == TransactionTypes.income;
    final category = await _categoryService.findOrCreateSystemCategory(
      name: isIncome ? 'Credit' : 'Debit',
      type: isIncome ? CategoryTypes.income : CategoryTypes.expense,
      icon: isIncome ? 'savings' : 'account_balance_wallet',
      colorHex: isIncome ? '#2563EB' : '#0F766E',
    );
    final now = DateTime.now();
    final transaction = TransactionModel()
      ..title = category.name
      ..amountMinor = parsed.amountMinor
      ..note = parsed.note
      ..transactionDate = parsed.smsReceivedAt
      ..categoryId = category.id
      ..subCategoryId = null
      ..paymentMethod = parsed.paymentMethod
      ..createdAt = now
      ..updatedAt = now
      ..transactionType = parsed.transactionType
      ..debtLoanKind = null
      ..parentTransactionId = null
      ..partyCsv = null
      ..excludeFromReports = false;
    final saved = await _transactionService.saveSmsTransactionIfNew(
      transaction,
    );
    if (!mounted || !saved) {
      return;
    }
    setState(() {
      _reloadToken++;
    });
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

  Future<void> _openDebtLoanScreen({int? focusedTransactionId}) async {
    final changed = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) => DebtLoanScreen(
          reloadToken: _reloadToken,
          settings: widget.settings,
          focusedTransactionId: focusedTransactionId,
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

  Future<void> _openSpendingsScreen() async {
    await Navigator.of(context).push<void>(
      AppRoute(
        builder: (_) => SpendingsScreen(
          settings: widget.settings,
          initialMonth: DateTime(DateTime.now().year, DateTime.now().month),
        ),
      ),
    );
  }

  Future<void> _openExportScreen() async {
    await Navigator.of(
      context,
    ).push<void>(AppRoute(builder: (_) => const ExportScreen()));
  }

  Future<void> _openSmsCompatibilityScreen() async {
    final changed = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) => SmsCompatibilityScreen(settings: widget.settings),
      ),
    );
    if (changed == true && mounted) {
      setState(() {
        _reloadToken++;
      });
    }
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
          onOpenDebtLoan: () => _openDebtLoanScreen(),
          onOpenDebtLoanTransaction: (transactionId) =>
              _openDebtLoanScreen(focusedTransactionId: transactionId),
          onOpenSpendings: _openSpendingsScreen,
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
          onOpenDebtLoan: () => _openDebtLoanScreen(),
          onOpenExport: _openExportScreen,
          onOpenProvisionalTransactions: _openProvisionalTransactionsScreen,
          onOpenSmsCompatibility: _openSmsCompatibilityScreen,
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
