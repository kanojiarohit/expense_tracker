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

  test('parses debit SMS without currency marker as expense', () {
    final parsed = parser.parse(
      smsBody: 'A/c XX1234 debited by 500.00 on 30/05/2026. Avl Bal 2000.',
      sender: 'VM-BANK',
      fallbackReceivedAt: fallbackDate,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amountMinor, 50000);
    expect(parsed.transactionType, TransactionTypes.expense);
    expect(parsed.smsReceivedAt, DateTime(2026, 5, 30));
  });

  test('parses credit SMS without currency marker as income', () {
    final parsed = parser.parse(
      smsBody: 'Account XX1234 credited with 2500 by NEFT.',
      sender: 'AD-BANK',
      fallbackReceivedAt: fallbackDate,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amountMinor, 250000);
    expect(parsed.transactionType, TransactionTypes.income);
    expect(parsed.paymentMethod, 'Bank Transfer');
  });

  test('parses credit for amount as income', () {
    final parsed = parser.parse(
      smsBody: 'Account XX1234 credit for 1250.75 by IMPS.',
      sender: 'AD-BANK',
      fallbackReceivedAt: fallbackDate,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amountMinor, 125075);
    expect(parsed.transactionType, TransactionTypes.income);
    expect(parsed.paymentMethod, 'Bank Transfer');
  });

  test('parses credit card spend SMS as expense', () {
    final parsed = parser.parse(
      smsBody: 'Your credit card used for Rs.850.00 at STORE on 30/05/2026.',
      sender: 'VK-CARD',
      fallbackReceivedAt: fallbackDate,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amountMinor, 85000);
    expect(parsed.transactionType, TransactionTypes.expense);
    expect(parsed.paymentMethod, 'Card');
  });

  test('parses transaction SMS with balance text after amount', () {
    final parsed = parser.parse(
      smsBody: 'Rs.1200 debited from A/c XX1234. Available balance Rs.9000.',
      sender: 'VK-BANK',
      fallbackReceivedAt: fallbackDate,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amountMinor, 120000);
    expect(parsed.transactionType, TransactionTypes.expense);
  });

  test('parses SBI UPI debit SMS with text date', () {
    final parsed = parser.parse(
      smsBody:
          'Dear UPI user A/C X1234 debited by 363.00 on date 25Jun26 trf to Blinkit Refno 617604741234 If not u? call-1800111109 for other services-18001234-SBI',
      sender: 'AD-SBI',
      fallbackReceivedAt: fallbackDate,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amountMinor, 36300);
    expect(parsed.transactionType, TransactionTypes.expense);
    expect(parsed.paymentMethod, 'UPI');
    expect(parsed.smsReceivedAt, DateTime(2026, 6, 25));
  });

  test('parses BOI UPI debit and credited merchant SMS as expense', () {
    final parsed = parser.parse(
      smsBody:
          'Rs.481.00 debited A/cXX1234 and credited to Blinkit via UPI Ref No 124943281234 on 18Jun26. Call 18001031906, if not done by you. -BOI',
      sender: 'VM-BOI',
      fallbackReceivedAt: fallbackDate,
    );

    expect(parsed, isNotNull);
    expect(parsed!.amountMinor, 48100);
    expect(parsed.transactionType, TransactionTypes.expense);
    expect(parsed.paymentMethod, 'UPI');
    expect(parsed.smsReceivedAt, DateTime(2026, 6, 18));
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

  test('ignores promo and statement messages without transaction signal', () {
    final promo = parser.parse(
      smsBody: 'Special offer: get discount vouchers worth Rs.500 today.',
      sender: 'VK-BANK',
      fallbackReceivedAt: fallbackDate,
    );
    final statement = parser.parse(
      smsBody: 'Your monthly statement for card XX1234 is ready.',
      sender: 'VK-BANK',
      fallbackReceivedAt: fallbackDate,
    );

    expect(promo, isNull);
    expect(statement, isNull);
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
