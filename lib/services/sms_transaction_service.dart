import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/formatters.dart';

class SmsTransactionDraft {
  const SmsTransactionDraft({
    required this.amountText,
    required this.transactionType,
    required this.note,
    required this.paymentMethod,
    this.transactionDate,
  });

  final String amountText;
  final String transactionType;
  final String note;
  final String paymentMethod;
  final DateTime? transactionDate;
}

class ParsedSmsTransaction {
  const ParsedSmsTransaction({
    required this.amountMinor,
    required this.transactionType,
    required this.note,
    required this.smsBody,
    required this.sender,
    required this.smsReceivedAt,
    required this.paymentMethod,
    required this.sourceKey,
  });

  final int amountMinor;
  final String transactionType;
  final String note;
  final String smsBody;
  final String sender;
  final DateTime smsReceivedAt;
  final String paymentMethod;
  final String sourceKey;
}

class SmsTransactionParser {
  const SmsTransactionParser();

  ParsedSmsTransaction? parse({
    required String smsBody,
    required String sender,
    required DateTime fallbackReceivedAt,
  }) {
    final note = smsBody.trim();
    if (note.isEmpty) {
      return null;
    }
    final text = note.toLowerCase();
    final transactionType = _transactionTypeFromSms(text);
    if (_shouldIgnoreSms(text, hasTransactionSignal: transactionType != null)) {
      return null;
    }
    if (transactionType == null) {
      return null;
    }
    final amount = _amountFromSms(note);
    if (amount == null) {
      return null;
    }
    final smsReceivedAt = _dateFromSms(note) ?? fallbackReceivedAt;
    return ParsedSmsTransaction(
      amountMinor: parseMinorAmount(amount),
      transactionType: transactionType,
      note: note,
      smsBody: note,
      sender: sender,
      smsReceivedAt: smsReceivedAt,
      paymentMethod: _paymentMethodFromSms(text),
      sourceKey: _sourceKeyFor(
        sender: sender,
        smsBody: note,
        receivedAt: smsReceivedAt,
      ),
    );
  }
}

class SmsTransactionService {
  SmsTransactionService({SmsTransactionParser? parser})
    : _parser = parser ?? const SmsTransactionParser();

  final SmsTransactionParser _parser;

  static const _methodChannel = MethodChannel(
    'expense_tracker/sms_permissions',
  );
  static const _eventChannel = EventChannel('expense_tracker/sms_events');

  Stream<ParsedSmsTransaction> get parsedTransactions {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) {
          if (event is! Map) {
            return null;
          }
          final body = event['body']?.toString() ?? '';
          final sender = event['sender']?.toString() ?? '';
          final receivedAtMillis = event['receivedAtMillis'] is int
              ? event['receivedAtMillis'] as int
              : DateTime.now().millisecondsSinceEpoch;
          return _parser.parse(
            smsBody: body,
            sender: sender,
            fallbackReceivedAt: DateTime.fromMillisecondsSinceEpoch(
              receivedAtMillis,
            ),
          );
        })
        .where((draft) => draft != null)
        .cast<ParsedSmsTransaction>();
  }

  Future<bool> hasSmsPermission() async {
    if (!_isAndroid) {
      return false;
    }
    final granted = await _methodChannel.invokeMethod<bool>('hasSmsPermission');
    return granted ?? false;
  }

  Future<bool> requestSmsPermission() async {
    if (!_isAndroid) {
      return false;
    }
    final granted = await _methodChannel.invokeMethod<bool>(
      'requestSmsPermission',
    );
    return granted ?? false;
  }

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
}

SmsTransactionDraft? parseTransactionSms(String sms) {
  final parsed = const SmsTransactionParser().parse(
    smsBody: sms,
    sender: '',
    fallbackReceivedAt: DateTime.now(),
  );
  if (parsed == null) {
    return null;
  }
  return SmsTransactionDraft(
    amountText: (parsed.amountMinor / 100).toStringAsFixed(2),
    transactionType: parsed.transactionType,
    note: parsed.note,
    paymentMethod: _paymentMethodFromSms(sms.toLowerCase()),
    transactionDate: parsed.smsReceivedAt,
  );
}

String? _transactionTypeFromSms(String text) {
  const debitWords = [
    'debited',
    'debit',
    'dr',
    'dr.',
    'debit card',
    'spent',
    'paid',
    'payment',
    'withdrawn',
    'purchase',
    'sent',
    'deducted',
    'charged',
    'txn',
  ];
  const creditWords = [
    'credited',
    'credit',
    'cr',
    'cr.',
    'received',
    'deposited',
    'refund',
    'cashback',
    'added',
  ];
  final debitIndex = _firstKeywordIndex(text, debitWords);
  final creditIndex = _firstKeywordIndex(text, creditWords);
  if (debitIndex == null && creditIndex == null) {
    return null;
  }
  if (debitIndex == null) {
    return TransactionTypes.income;
  }
  if (creditIndex == null) {
    return TransactionTypes.expense;
  }
  return creditIndex < debitIndex
      ? TransactionTypes.income
      : TransactionTypes.expense;
}

bool _shouldIgnoreSms(String text, {required bool hasTransactionSignal}) {
  const ignoredWords = [
    'otp',
    'one time password',
    'verification code',
    'do not share',
    'statement',
    'offer',
    'discount',
    'sale',
  ];
  if (ignoredWords.any(text.contains)) {
    return true;
  }
  return !hasTransactionSignal &&
      (text.contains('available balance') || text.contains('balance is'));
}

int? _firstKeywordIndex(String text, List<String> keywords) {
  int? first;
  for (final keyword in keywords) {
    final index = text.indexOf(keyword);
    if (index >= 0 && (first == null || index < first)) {
      first = index;
    }
  }
  return first;
}

String? _amountFromSms(String sms) {
  final patterns = [
    RegExp(
      r'(?:INR|Rs\.?|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:INR|Rs\.?)',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(sms);
    if (match != null) {
      return match.group(1)?.replaceAll(',', '');
    }
  }
  return null;
}

String _paymentMethodFromSms(String text) {
  if (text.contains('upi') ||
      text.contains('vpa') ||
      text.contains('paytm') ||
      text.contains('phonepe') ||
      text.contains('gpay') ||
      text.contains('google pay')) {
    return 'UPI';
  }
  if (text.contains('card') ||
      text.contains('debit card') ||
      text.contains('credit card') ||
      text.contains('pos')) {
    return 'Card';
  }
  if (text.contains('neft') ||
      text.contains('imps') ||
      text.contains('rtgs') ||
      text.contains('bank transfer') ||
      text.contains('bank account')) {
    return 'Bank Transfer';
  }
  if (text.contains('atm') || text.contains('cash withdrawal')) {
    return 'Cash';
  }
  return 'Other';
}

String _sourceKeyFor({
  required String sender,
  required String smsBody,
  required DateTime receivedAt,
}) {
  final value =
      '${sender.trim().toLowerCase()}|${receivedAt.millisecondsSinceEpoch}|${smsBody.trim()}';
  return _fnv1a64(value);
}

String _fnv1a64(String value) {
  const mask = 0x7fffffffffffffff;
  var hash = 0xcbf29ce484222325 & mask;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

DateTime? _dateFromSms(String sms) {
  final patterns = [RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b')];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(sms);
    if (match == null) {
      continue;
    }
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final rawYear = int.tryParse(match.group(3)!);
    if (day == null || month == null || rawYear == null) {
      continue;
    }
    final year = rawYear < 100 ? 2000 + rawYear : rawYear;
    return DateTime(year, month, day);
  }
  return null;
}
