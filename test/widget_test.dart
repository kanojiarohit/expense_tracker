import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/core/constants.dart';
import 'package:expense_tracker/services/sms_transaction_service.dart';

void main() {
  test('sanity', () {
    expect(1 + 1, 2);
  });

  test('parses debit transaction sms', () {
    final draft = parseTransactionSms(
      'Rs. 1,250.50 debited from A/c XX1234 via UPI. Balance is Rs. 5000.',
    );

    expect(draft?.amountText, '1250.50');
    expect(draft?.transactionType, TransactionTypes.expense);
    expect(draft?.paymentMethod, 'UPI');
  });

  test('parses credit transaction sms', () {
    final draft = parseTransactionSms(
      'INR 2000 credited to your bank account from ACME.',
    );

    expect(draft?.amountText, '2000.00');
    expect(draft?.transactionType, TransactionTypes.income);
    expect(draft?.paymentMethod, 'Bank Transfer');
  });
}
