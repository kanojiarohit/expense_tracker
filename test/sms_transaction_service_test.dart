import 'package:expense_tracker/core/constants.dart';
import 'package:expense_tracker/services/sms_transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = SmsTransactionParser();
  final fallbackDate = DateTime(2026, 5, 30, 12);

  test('parses debit bank SMS as expense', () {
    final parsed = parser.parse(
      smsBody:
          'INR 1,234.50 debited from A/c XX1234 via UPI on 30/05/2026. Ref 42.',
      sender: 'VK-BANK',
      fallbackReceivedAt: fallbackDate,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amountMinor, 123450);
    expect(parsed.transactionType, TransactionTypes.expense);
    expect(parsed.paymentMethod, 'UPI');
    expect(parsed.smsReceivedAt, DateTime(2026, 5, 30));
    expect(parsed.sourceKey, isNotEmpty);
  });

  test('parses credit SMS as income', () {
    final parsed = parser.parse(
      smsBody: 'Rs.5000 credited to your account by NEFT.',
      sender: 'AD-BANK',
      fallbackReceivedAt: fallbackDate,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amountMinor, 500000);
    expect(parsed.transactionType, TransactionTypes.income);
    expect(parsed.paymentMethod, 'Bank Transfer');
  });

  test('ignores OTP and balance messages', () {
    final otp = parser.parse(
      smsBody: 'Your OTP is 123456. Do not share it with anyone.',
      sender: 'VK-BANK',
      fallbackReceivedAt: fallbackDate,
    );
    final balance = parser.parse(
      smsBody: 'Available balance in your account is INR 10,000.',
      sender: 'VK-BANK',
      fallbackReceivedAt: fallbackDate,
    );

    expect(otp, isNull);
    expect(balance, isNull);
  });

  test('creates stable source key for same SMS payload', () {
    final first = parser.parse(
      smsBody: 'INR 250 paid using card at STORE.',
      sender: 'VK-BANK',
      fallbackReceivedAt: fallbackDate,
    );
    final second = parser.parse(
      smsBody: 'INR 250 paid using card at STORE.',
      sender: 'VK-BANK',
      fallbackReceivedAt: fallbackDate,
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.sourceKey, second!.sourceKey);
  });
}
