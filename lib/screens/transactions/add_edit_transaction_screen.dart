import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../models/transaction.dart';
import '../../services/sms_transaction_service.dart';
import '../../services/transaction_service.dart';
import 'transaction_form.dart';

class AddEditTransactionScreen extends StatelessWidget {
  const AddEditTransactionScreen({
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

  bool get _isEditing => transaction != null;

  Future<void> _delete(BuildContext context) async {
    final currentTransaction = transaction;
    if (currentTransaction == null) {
      return;
    }
    try {
      await TransactionService().delete(currentTransaction);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: TransactionForm(
        transaction: transaction,
        forcedDebtLoanKind: forcedDebtLoanKind,
        parentTransaction: parentTransaction,
        initialDraft: initialDraft,
        settings: settings,
      ),
    );
  }
}
