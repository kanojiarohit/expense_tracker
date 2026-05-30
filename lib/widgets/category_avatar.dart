import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/category.dart';
import '../theme/app_colors.dart';

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    this.category,
    this.name,
    this.type,
    this.debtLoanKind,
    this.radius = 20,
  });

  final CategoryModel? category;
  final String? name;
  final String? type;
  final String? debtLoanKind;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final resolvedName = name ?? category?.name ?? 'Category';
    final color = _semanticColor(
      type ?? category?.type,
      debtLoanKind: debtLoanKind,
      name: resolvedName,
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Text(
        categoryInitials(resolvedName),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

String categoryInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    final word = parts.first.toUpperCase();
    return word.characters.take(2).toString();
  }
  return parts
      .map((part) => part.characters.first.toUpperCase())
      .take(2)
      .join();
}

Color _semanticColor(
  String? type, {
  String? debtLoanKind,
  required String name,
}) {
  if (type == CategoryTypes.income) {
    return AppColors.success;
  }
  if (type == CategoryTypes.debtLoan) {
    final kind = debtLoanKind ?? _debtLoanKindFromCategoryName(name);
    return debtLoanKindIsInflow(kind) ? AppColors.success : AppColors.accent;
  }
  return AppColors.danger;
}

String? _debtLoanKindFromCategoryName(String name) {
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
      return null;
  }
}
