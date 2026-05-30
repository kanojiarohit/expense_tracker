import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/category.dart';
import '../../navigation/app_route.dart';
import '../../services/category_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/category_avatar.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_category_screen.dart';

class SelectCategoryScreen extends StatefulWidget {
  const SelectCategoryScreen({
    super.key,
    required this.type,
    this.selectedCategoryId,
    this.parentOnly = false,
    this.includeNoParent = false,
    this.excludedCategoryId,
    this.showAddButton = true,
    this.title,
  });

  final String type;
  final int? selectedCategoryId;
  final bool parentOnly;
  final bool includeNoParent;
  final int? excludedCategoryId;
  final bool showAddButton;
  final String? title;

  @override
  State<SelectCategoryScreen> createState() => _SelectCategoryScreenState();
}

class CategorySelectionResult {
  const CategorySelectionResult({this.category, this.cleared = false});

  final CategoryModel? category;
  final bool cleared;
}

class _SelectCategoryScreenState extends State<SelectCategoryScreen> {
  final CategoryService _categoryService = CategoryService();
  final _searchController = TextEditingController();

  bool _loading = true;
  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final categories = await _categoryService.fetchByType(widget.type);
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _addCategory() async {
    final saved = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) =>
            AddEditCategoryScreen(initialType: widget.type, lockType: true),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  List<CategoryModel> get _visibleRoots {
    final query = _searchController.text.trim().toLowerCase();
    final roots = _categories.where((category) {
      if (category.parentCategoryId != null) {
        return false;
      }
      if (category.id == widget.excludedCategoryId) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final childMatches = _childrenFor(
        category,
        applyQuery: false,
      ).any((child) => child.name.toLowerCase().contains(query));
      return category.name.toLowerCase().contains(query) || childMatches;
    }).toList();
    roots.sort((a, b) => a.name.compareTo(b.name));
    return roots;
  }

  List<CategoryModel> _childrenFor(
    CategoryModel parent, {
    bool applyQuery = true,
  }) {
    final query = _searchController.text.trim().toLowerCase();
    final children = _categories.where((category) {
      if (category.parentCategoryId != parent.id) {
        return false;
      }
      if (category.id == widget.excludedCategoryId) {
        return false;
      }
      if (!applyQuery || query.isEmpty) {
        return true;
      }
      return category.name.toLowerCase().contains(query) ||
          parent.name.toLowerCase().contains(query);
    }).toList();
    children.sort((a, b) => a.name.compareTo(b.name));
    return children;
  }

  String _categoryTitle(CategoryModel category) {
    if (widget.type != CategoryTypes.debtLoan ||
        category.parentCategoryId != null) {
      return category.name;
    }
    return debtLoanLabel(_kindFromCategoryName(category.name));
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
    final roots = _visibleRoots;
    final showNoParent =
        widget.includeNoParent && _searchController.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Select Category'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (widget.showAddButton)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton.filled(
                onPressed: _addCategory,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add category',
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: AppTextField(
                      controller: _searchController,
                      label: 'Search categories',
                      suffix: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: roots.isEmpty && !showNoParent
                        ? const EmptyState(
                            title: 'No categories found',
                            description:
                                'Add a new category or change your search.',
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              if (showNoParent)
                                AppCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  borderRadius: 8,
                                  child: _CategoryRow(
                                    title: 'No parent',
                                    icon: Icons.layers_clear_outlined,
                                    selected: widget.selectedCategoryId == null,
                                    onTap: () => Navigator.of(context).pop(
                                      const CategorySelectionResult(
                                        cleared: true,
                                      ),
                                    ),
                                  ),
                                ),
                              for (final root in roots)
                                AppCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  borderRadius: 8,
                                  child: Column(
                                    children: [
                                      _CategoryRow(
                                        category: root,
                                        title: _categoryTitle(root),
                                        selected:
                                            root.id ==
                                            widget.selectedCategoryId,
                                        onTap: () => Navigator.of(context).pop(
                                          CategorySelectionResult(
                                            category: root,
                                          ),
                                        ),
                                      ),
                                      if (!widget.parentOnly)
                                        for (final child in _childrenFor(root))
                                          _CategoryRow(
                                            category: child,
                                            title: _categoryTitle(child),
                                            selected:
                                                child.id ==
                                                widget.selectedCategoryId,
                                            indent: 28,
                                            onTap: () =>
                                                Navigator.of(context).pop(
                                                  CategorySelectionResult(
                                                    category: child,
                                                  ),
                                                ),
                                          ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    this.category,
    required this.title,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.indent = 0,
  });

  final CategoryModel? category;
  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final bool selected;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    final color = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(indent, 8, 0, 8),
        child: Row(
          children: [
            category == null
                ? CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.16),
                    child: Icon(icon ?? Icons.category, color: color),
                  )
                : CategoryAvatar(category: category),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
