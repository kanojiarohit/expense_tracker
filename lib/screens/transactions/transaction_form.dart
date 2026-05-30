import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../models/app_settings.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../navigation/app_route.dart';
import '../../screens/categories/select_category_screen.dart';
import '../../services/category_service.dart';
import '../../services/sms_transaction_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class TransactionForm extends StatefulWidget {
  const TransactionForm({
    super.key,
    this.transaction,
    this.forcedDebtLoanKind,
    this.parentTransaction,
    this.initialDraft,
    required this.settings,
  });

  final TransactionModel? transaction;
  final String? forcedDebtLoanKind;
  final TransactionModel? parentTransaction;
  final SmsTransactionDraft? initialDraft;
  final AppSettingsModel settings;

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  final _partyController = TextEditingController();
  final CategoryService _categoryService = CategoryService();
  final TransactionService _transactionService = TransactionService();
  static const EdgeInsets _fieldPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 18,
  );

  bool _saving = false;
  String _transactionType = TransactionTypes.expense;
  String? _selectedDebtLoanKind;
  int? _selectedCategoryId;
  int? _selectedParentTransactionId;
  String _paymentMethod = PaymentMethods.values.first;
  bool _excludeFromReports = false;
  DateTime _selectedDate = DateTime.now();
  List<CategoryModel> _categories = [];
  List<TransactionRecord> _parentOptions = [];

  bool get _isEditing => widget.transaction != null;
  bool get _isDebtLoan => _transactionType == TransactionTypes.debtLoan;
  String get _categoryType =>
      _isDebtLoan ? CategoryTypes.debtLoan : _transactionType;
  bool get _isPaybackKind =>
      _selectedDebtLoanKind == DebtLoanKinds.debtCollection ||
      _selectedDebtLoanKind == DebtLoanKinds.loanRepayment;
  TransactionRecord? get _selectedParentOption => _parentOptions
      .where((item) => item.transaction.id == _selectedParentTransactionId)
      .cast<TransactionRecord?>()
      .firstWhere((_) => true, orElse: () => null);

  @override
  void initState() {
    super.initState();
    _seedForm();
    _load();
  }

  void _seedForm() {
    final transaction = widget.transaction;
    if (transaction == null) {
      final draft = widget.initialDraft;
      _transactionType =
          draft?.transactionType ??
          (widget.forcedDebtLoanKind == null
              ? TransactionTypes.expense
              : TransactionTypes.debtLoan);
      _selectedDebtLoanKind = widget.forcedDebtLoanKind;
      _selectedDate = draft?.transactionDate ?? DateTime.now();
      _paymentMethod = draft?.paymentMethod ?? PaymentMethods.values.first;
      _excludeFromReports = widget.forcedDebtLoanKind != null;
      _selectedParentTransactionId = widget.parentTransaction?.id;
      if (draft != null) {
        _amountController.text = draft.amountText;
        _noteController.text = draft.note;
      }
      if (widget.parentTransaction?.partyCsv?.isNotEmpty == true) {
        _partyController.text = widget.parentTransaction!.partyCsv!;
      }
      return;
    }

    _amountController.text = (transaction.amountMinor / 100).toStringAsFixed(2);
    _noteController.text = transaction.note;
    _partyController.text = transaction.partyCsv ?? '';
    _transactionType = transaction.transactionType;
    _selectedDebtLoanKind = transaction.debtLoanKind;
    _selectedCategoryId = transaction.categoryId;
    _paymentMethod = transaction.paymentMethod;
    _excludeFromReports = transaction.excludeFromReports;
    _selectedDate = transaction.transactionDate;
    _selectedParentTransactionId = transaction.parentTransactionId;
  }

  Future<void> _load() async {
    final categories = await _categoryService.fetchAll();
    final kind = _selectedDebtLoanKind;
    final parentOptions = kind == null || !_isPaybackKind
        ? <TransactionRecord>[]
        : await _transactionService.fetchAvailableParents(
            kind,
            ignoreTransactionId: widget.transaction?.id,
          );
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
      _parentOptions = parentOptions;
      _selectedCategoryId ??= _resolveDefaultCategoryId();
      _selectedDebtLoanKind ??= _resolveKindFromCategoryId(_selectedCategoryId);
      _syncCategoryText();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _partyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final transaction = widget.transaction ?? TransactionModel();
      transaction
        ..title = _resolvedTransactionTitle()
        ..amountMinor = parseMinorAmount(_amountController.text)
        ..note = _noteController.text.trim()
        ..transactionDate = _selectedDate
        ..categoryId = _selectedCategoryId!
        ..subCategoryId = null
        ..paymentMethod = _paymentMethod
        ..transactionType = _transactionType
        ..debtLoanKind = _isDebtLoan ? _selectedDebtLoanKind : null
        ..parentTransactionId = _isPaybackKind
            ? _selectedParentTransactionId
            : null
        ..partyCsv = _isDebtLoan ? _partyController.text.trim() : null
        ..excludeFromReports = _excludeFromReports
        ..createdAt = widget.transaction?.createdAt ?? DateTime.now()
        ..updatedAt = DateTime.now();
      await _transactionService.save(transaction);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  int? _resolveDefaultCategoryId() {
    if (_isDebtLoan && _selectedDebtLoanKind != null) {
      final match = _categories
          .where((item) => item.type == CategoryTypes.debtLoan)
          .cast<CategoryModel?>()
          .firstWhere(
            (item) =>
                _kindFromCategoryName(item?.name) == _selectedDebtLoanKind,
            orElse: () => null,
          );
      return match?.id;
    }
    return _categories
        .where(
          (item) => item.type == _categoryType && item.parentCategoryId == null,
        )
        .map((item) => item.id)
        .cast<int?>()
        .firstWhere((_) => true, orElse: () => null);
  }

  String? _resolveKindFromCategoryId(int? categoryId) {
    final category = _categories
        .where((item) => item.id == categoryId)
        .cast<CategoryModel?>()
        .firstWhere((_) => true, orElse: () => null);
    if (category == null) {
      return _selectedDebtLoanKind;
    }
    if (category.parentCategoryId != null) {
      final parent = _categories
          .where((item) => item.id == category.parentCategoryId)
          .cast<CategoryModel?>()
          .firstWhere((_) => true, orElse: () => null);
      return _kindFromCategoryName(parent?.name);
    }
    return _kindFromCategoryName(category.name);
  }

  String _resolvedTransactionTitle() {
    if (_isDebtLoan) {
      return debtLoanLabel(_selectedDebtLoanKind);
    }
    final category = _categories
        .where((item) => item.id == _selectedCategoryId)
        .cast<CategoryModel?>()
        .firstWhere((_) => true, orElse: () => null);
    return category?.name ?? 'Transaction';
  }

  void _syncCategoryText() {
    final category = _categories
        .where((item) => item.id == _selectedCategoryId)
        .cast<CategoryModel?>()
        .firstWhere((_) => true, orElse: () => null);
    if (category == null) {
      _categoryController.text = '';
      return;
    }
    if (_isDebtLoan && category.parentCategoryId == null) {
      _categoryController.text = debtLoanLabel(
        _kindFromCategoryName(category.name),
      );
      return;
    }
    _categoryController.text = category.name;
  }

  Future<void> _openCategoryPicker() async {
    final result = await Navigator.of(context).push<CategorySelectionResult>(
      AppRoute(
        builder: (_) => SelectCategoryScreen(
          type: _categoryType,
          selectedCategoryId: _selectedCategoryId,
        ),
      ),
    );
    final categories = await _categoryService.fetchAll();
    if (!mounted) {
      return;
    }
    final category = result?.category;
    setState(() {
      _categories = categories;
      if (category != null) {
        _selectedCategoryId = category.id;
        _selectedDebtLoanKind = _resolveKindFromCategoryId(category.id);
      }
      _syncCategoryText();
    });
    if (category != null && _isDebtLoan) {
      _load();
    }
  }

  String _kindFromCategoryName(String? name) {
    switch (name) {
      case 'Debt':
        return DebtLoanKinds.debt;
      case 'Debt Collection':
        return DebtLoanKinds.debtCollection;
      case 'Loan':
        return DebtLoanKinds.loan;
      case 'Loan Repayment':
        return DebtLoanKinds.loanRepayment;
      default:
        return DebtLoanKinds.debt;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: TransactionTypes.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: TransactionTypes.income,
                  label: Text('Income'),
                ),
                ButtonSegment(
                  value: TransactionTypes.debtLoan,
                  label: Text('Loans/Debts'),
                ),
              ],
              selected: {_transactionType},
              onSelectionChanged: widget.forcedDebtLoanKind != null
                  ? null
                  : (value) {
                      setState(() {
                        _transactionType = value.first;
                        _selectedParentTransactionId = null;
                        _excludeFromReports =
                            _transactionType == TransactionTypes.debtLoan;
                        _selectedCategoryId = _resolveDefaultCategoryId();
                        _selectedDebtLoanKind = _resolveKindFromCategoryId(
                          _selectedCategoryId,
                        );
                        _syncCategoryText();
                      });
                      _load();
                    },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _amountController,
              label: 'Amount',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: positiveAmountValidator,
              contentPadding: _fieldPadding,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _categoryController,
              label: 'Category',
              readOnly: true,
              onTap: _openCategoryPicker,
              suffix: const Icon(Icons.expand_more),
              validator: (_) =>
                  _selectedCategoryId == null ? 'Select category' : null,
              contentPadding: _fieldPadding,
            ),
            if (_isDebtLoan) ...[
              const SizedBox(height: 18),
              AppTextField(
                controller: _partyController,
                label: 'Lender / Borrower',
                hintText: 'Rahul, Priya',
                validator: (value) =>
                    requiredValidator(value, 'Lender / Borrower'),
                contentPadding: _fieldPadding,
              ),
              if (_isPaybackKind) ...[
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  initialValue: _selectedParentTransactionId,
                  decoration: InputDecoration(
                    labelText:
                        _selectedDebtLoanKind == DebtLoanKinds.debtCollection
                        ? 'Which Loan?'
                        : 'Which Debt?',
                    contentPadding: _fieldPadding,
                  ),
                  items: _parentOptions
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.transaction.id,
                          child: Text(
                            '${item.transaction.partyCsv ?? item.transaction.title} • ${formatMinorAmount(item.transaction.amountMinor, currency: widget.settings.currency, amountFormat: widget.settings.amountFormat)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedParentTransactionId = value;
                    final parent = _selectedParentOption?.transaction;
                    if (parent?.partyCsv?.isNotEmpty == true) {
                      _partyController.text = parent!.partyCsv!;
                    }
                  }),
                ),
              ],
            ],
            const SizedBox(height: 18),
            AppTextField(
              controller: _noteController,
              label: 'Note',
              maxLines: 3,
              contentPadding: _fieldPadding,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: TextEditingController(
                text: formatDate(_selectedDate, SettingValues.dateIso),
              ),
              label: 'Transaction date',
              readOnly: true,
              onTap: _pickDate,
              suffix: const Icon(Icons.calendar_today_outlined),
              contentPadding: _fieldPadding,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                contentPadding: _fieldPadding,
              ),
              items: PaymentMethods.values
                  .map(
                    (method) => DropdownMenuItem<String>(
                      value: method,
                      child: Text(method),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => _paymentMethod = value ?? PaymentMethods.values.first,
              ),
            ),
            const SizedBox(height: 18),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude from reports'),
              subtitle: const Text(
                'Transaction still appears in history and balance',
              ),
              value: _excludeFromReports,
              onChanged: (value) => setState(() => _excludeFromReports = value),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: _isEditing ? 'Save Changes' : 'Save Transaction',
              onPressed: _saving ? null : _save,
              isLoading: _saving,
              icon: Icons.check_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
