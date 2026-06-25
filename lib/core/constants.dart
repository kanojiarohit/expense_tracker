import 'package:flutter/material.dart';

class AppStrings {
  static const appName = 'Expense Tracker';
}

class CategoryTypes {
  static const expense = 'expense';
  static const income = 'income';
  static const debtLoan = 'debtLoan';
}

class TransactionTypes {
  static const expense = 'expense';
  static const income = 'income';
  static const debtLoan = 'debtLoan';
}

class DebtLoanKinds {
  static const debt = 'debt';
  static const debtCollection = 'debtCollection';
  static const loan = 'loan';
  static const loanRepayment = 'loanRepayment';

  static const labels = {
    debt: 'Debt (money you borrowed)',
    debtCollection: 'Debt Collection (money you got back)',
    loan: 'Loan (money you gave)',
    loanRepayment: 'Loan Repayment (money you paid back)',
  };
}

class SettingValues {
  static const themeSystem = 'system';
  static const themeLight = 'light';
  static const themeDark = 'dark';

  static const indianAmountFormat = 'indian';
  static const internationalAmountFormat = 'international';

  static const dateDdMmYyyy = 'DD/MM/YYYY';
  static const dateMmDdYyyy = 'MM/DD/YYYY';
  static const dateIso = 'YYYY-MM-DD';
  static const dateLong = 'D MMM YYYY';

  static const smsImportProvisional = 'provisional';
  static const smsImportMainTransaction = 'mainTransaction';

  static const appLockImmediate = 'immediate';
  static const appLockAfter1Minute = 'after1Minute';
  static const appLockAfter30Minutes = 'after30Minutes';
}

class PaymentMethods {
  static const values = ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Other'];
}

class FilterValues {
  static const all = 'all';
  static const included = 'included';
  static const excluded = 'excluded';
}

class SeedCategory {
  const SeedCategory({
    required this.name,
    required this.type,
    required this.icon,
    required this.colorHex,
    this.parentName,
    this.isSystem = false,
  });

  final String name;
  final String type;
  final String icon;
  final String colorHex;
  final String? parentName;
  final bool isSystem;
}

const seededCategories = <SeedCategory>[
  SeedCategory(
    name: 'Debit',
    type: CategoryTypes.expense,
    icon: 'account_balance_wallet',
    colorHex: '#0F766E',
    isSystem: true,
  ),
  SeedCategory(
    name: 'Food',
    type: CategoryTypes.expense,
    icon: 'restaurant',
    colorHex: '#2563EB',
  ),
  SeedCategory(
    name: 'Groceries',
    type: CategoryTypes.expense,
    icon: 'shopping_cart',
    colorHex: '#38BDF8',
    parentName: 'Food',
  ),
  SeedCategory(
    name: 'Restaurants',
    type: CategoryTypes.expense,
    icon: 'lunch_dining',
    colorHex: '#0EA5E9',
    parentName: 'Food',
  ),
  SeedCategory(
    name: 'Transport',
    type: CategoryTypes.expense,
    icon: 'directions_bus',
    colorHex: '#16A34A',
  ),
  SeedCategory(
    name: 'Fuel',
    type: CategoryTypes.expense,
    icon: 'local_gas_station',
    colorHex: '#22C55E',
    parentName: 'Transport',
  ),
  SeedCategory(
    name: 'Shopping',
    type: CategoryTypes.expense,
    icon: 'shopping_bag',
    colorHex: '#DB2777',
  ),
  SeedCategory(
    name: 'Bills',
    type: CategoryTypes.expense,
    icon: 'receipt_long',
    colorHex: '#F97316',
  ),
  SeedCategory(
    name: 'Health',
    type: CategoryTypes.expense,
    icon: 'health_and_safety',
    colorHex: '#DC2626',
  ),
  SeedCategory(
    name: 'Entertainment',
    type: CategoryTypes.expense,
    icon: 'movie',
    colorHex: '#7C3AED',
  ),
  SeedCategory(
    name: 'Other',
    type: CategoryTypes.expense,
    icon: 'category',
    colorHex: '#64748B',
  ),
  SeedCategory(
    name: 'Credit',
    type: CategoryTypes.income,
    icon: 'savings',
    colorHex: '#2563EB',
    isSystem: true,
  ),
  SeedCategory(
    name: 'Salary',
    type: CategoryTypes.income,
    icon: 'work',
    colorHex: '#16A34A',
  ),
  SeedCategory(
    name: 'Freelance',
    type: CategoryTypes.income,
    icon: 'laptop_mac',
    colorHex: '#0891B2',
  ),
  SeedCategory(
    name: 'Gift',
    type: CategoryTypes.income,
    icon: 'redeem',
    colorHex: '#D946EF',
  ),
  SeedCategory(
    name: 'Refund',
    type: CategoryTypes.income,
    icon: 'replay',
    colorHex: '#0F766E',
  ),
  SeedCategory(
    name: 'Other Income',
    type: CategoryTypes.income,
    icon: 'attach_money',
    colorHex: '#64748B',
  ),
  SeedCategory(
    name: 'Debt',
    type: CategoryTypes.debtLoan,
    icon: 'south_west',
    colorHex: '#16A34A',
    isSystem: true,
  ),
  SeedCategory(
    name: 'Debt Collection',
    type: CategoryTypes.debtLoan,
    icon: 'move_to_inbox',
    colorHex: '#22C55E',
    isSystem: true,
  ),
  SeedCategory(
    name: 'Loan',
    type: CategoryTypes.debtLoan,
    icon: 'north_east',
    colorHex: '#DC2626',
    isSystem: true,
  ),
  SeedCategory(
    name: 'Loan Repayment',
    type: CategoryTypes.debtLoan,
    icon: 'payments',
    colorHex: '#F97316',
    isSystem: true,
  ),
];

const categoryIconChoices = <String>[
  'restaurant',
  'shopping_cart',
  'shopping_bag',
  'receipt_long',
  'health_and_safety',
  'movie',
  'work',
  'wallet',
  'account_balance_wallet',
  'savings',
  'directions_bus',
  'category',
];

const categoryColorChoices = <String>[
  '#2563EB',
  '#38BDF8',
  '#16A34A',
  '#22C55E',
  '#DB2777',
  '#F97316',
  '#DC2626',
  '#7C3AED',
  '#0891B2',
  '#64748B',
];

const cardRadius = 18.0;

bool debtLoanKindIsInflow(String? kind) {
  return kind == DebtLoanKinds.debt || kind == DebtLoanKinds.debtCollection;
}

String debtLoanLabel(String? kind) => DebtLoanKinds.labels[kind] ?? kind ?? '';

IconData iconForName(String name) {
  switch (name) {
    case 'restaurant':
      return Icons.restaurant;
    case 'shopping_cart':
      return Icons.shopping_cart;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'receipt_long':
      return Icons.receipt_long;
    case 'health_and_safety':
      return Icons.health_and_safety;
    case 'movie':
      return Icons.movie;
    case 'work':
      return Icons.work;
    case 'wallet':
      return Icons.account_balance_wallet_outlined;
    case 'directions_bus':
      return Icons.directions_bus;
    case 'local_gas_station':
      return Icons.local_gas_station;
    case 'lunch_dining':
      return Icons.lunch_dining;
    case 'replay':
      return Icons.replay;
    case 'laptop_mac':
      return Icons.laptop_mac;
    case 'attach_money':
      return Icons.attach_money;
    case 'redeem':
      return Icons.redeem;
    case 'south_west':
      return Icons.south_west;
    case 'move_to_inbox':
      return Icons.move_to_inbox;
    case 'north_east':
      return Icons.north_east;
    case 'payments':
      return Icons.payments;
    default:
      return Icons.category;
  }
}
