import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/category.dart';
import '../../navigation/app_route.dart';
import '../../services/category_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/category_avatar.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_category_screen.dart';

class SelectCategoryScreen extends StatefulWidget {
  const SelectCategoryScreen({
    super.key,
    this.type,
    this.selectedCategoryId,
    this.selectedCategoryIds = const {},
    this.multiSelect = false,
    this.parentOnly = false,
    this.includeNoParent = false,
    this.excludedCategoryId,
    this.showAddButton = true,
    this.title,
  });

  final String? type;
  final int? selectedCategoryId;
  final Set<int> selectedCategoryIds;
  final bool multiSelect;
  final bool parentOnly;
  final bool includeNoParent;
  final int? excludedCategoryId;
  final bool showAddButton;
  final String? title;

  @override
  State<SelectCategoryScreen> createState() => _SelectCategoryScreenState();
}

class CategorySelectionResult {
  const CategorySelectionResult({
    this.category,
    this.categories,
    this.cleared = false,
  });

  final CategoryModel? category;
  final List<CategoryModel>? categories;
  final bool cleared;
}

class _SelectCategoryScreenState extends State<SelectCategoryScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (label: 'Expense', type: CategoryTypes.expense),
    (label: 'Income', type: CategoryTypes.income),
    (label: 'Debt/Loan', type: CategoryTypes.debtLoan),
  ];

  final CategoryService _categoryService = CategoryService();
  final _searchController = TextEditingController();

  TabController? _tabController;
  bool _loading = true;
  List<CategoryModel> _categories = [];
  late Set<int> _selectedCategoryIds;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = {...widget.selectedCategoryIds};
    if (widget.selectedCategoryId != null) {
      _selectedCategoryIds.add(widget.selectedCategoryId!);
    }
    if (widget.type == null) {
      _tabController = TabController(length: _tabs.length, vsync: this)
        ..addListener(() => setState(() {}));
    }
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final type = widget.type;
    final categories = type == null
        ? await _categoryService.fetchAll()
        : await _categoryService.fetchByType(type);
    if (!mounted) {
      return;
    }
    _syncSelectedTab(categories);
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  void _syncSelectedTab(List<CategoryModel> categories) {
    final controller = _tabController;
    if (controller == null || _selectedCategoryIds.isEmpty) {
      return;
    }
    final selectedId = widget.selectedCategoryId ?? _selectedCategoryIds.first;
    final selected = categories
        .where((category) => category.id == selectedId)
        .cast<CategoryModel?>()
        .firstWhere((_) => true, orElse: () => null);
    if (selected == null) {
      return;
    }
    final index = _tabs.indexWhere((tab) => tab.type == selected.type);
    if (index >= 0) {
      controller.index = index;
    }
  }

  Future<void> _addCategory() async {
    final type = widget.type;
    if (type == null) {
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) =>
            AddEditCategoryScreen(initialType: type, lockType: true),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  void _finishMultiSelect() {
    final selected = _categories
        .where((category) => _selectedCategoryIds.contains(category.id))
        .toList();
    Navigator.of(context).pop(CategorySelectionResult(categories: selected));
  }

  void _toggleCategory(CategoryModel category) {
    setState(() {
      if (_selectedCategoryIds.contains(category.id)) {
        _selectedCategoryIds.remove(category.id);
      } else {
        _selectedCategoryIds.add(category.id);
      }
    });
  }

  bool _isSelected(CategoryModel category) {
    return widget.multiSelect
        ? _selectedCategoryIds.contains(category.id)
        : category.id == widget.selectedCategoryId;
  }

  List<CategoryModel> _visibleRootsFor(String type) {
    final query = _searchController.text.trim().toLowerCase();
    final roots = _categories.where((category) {
      if (category.type != type) {
        return false;
      }
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
    if (category.type != CategoryTypes.debtLoan ||
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
    final type = widget.type;
    final tabController = _tabController;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Select Category'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (widget.showAddButton && widget.type != null)
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
      bottomNavigationBar: widget.multiSelect
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'Done',
                    icon: Icons.check_rounded,
                    onPressed: _finishMultiSelect,
                  ),
                ),
              ),
            )
          : null,
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
                  if (type == null && tabController != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TabBar(
                        controller: tabController,
                        tabs: [for (final tab in _tabs) Tab(text: tab.label)],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: tabController,
                        children: [
                          for (final tab in _tabs) _categoryList(tab.type),
                        ],
                      ),
                    ),
                  ] else
                    Expanded(child: _categoryList(type!)),
                ],
              ),
      ),
    );
  }

  Widget _categoryList(String type) {
    final roots = _visibleRootsFor(type);
    final showNoParent =
        widget.type != null &&
        widget.includeNoParent &&
        _searchController.text.trim().isEmpty;

    if (roots.isEmpty && !showNoParent) {
      return const EmptyState(
        title: 'No categories found',
        description: 'Add a new category or change your search.',
      );
    }

    return ListView(
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
              onTap: () => Navigator.of(
                context,
              ).pop(const CategorySelectionResult(cleared: true)),
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
                  selected: _isSelected(root),
                  showSelectionControl: widget.multiSelect,
                  onTap: widget.multiSelect
                      ? () => _toggleCategory(root)
                      : () => Navigator.of(
                          context,
                        ).pop(CategorySelectionResult(category: root)),
                ),
                if (!widget.parentOnly)
                  for (final child in _childrenFor(root))
                    _CategoryRow(
                      category: child,
                      title: _categoryTitle(child),
                      selected: _isSelected(child),
                      showSelectionControl: widget.multiSelect,
                      indent: 28,
                      onTap: widget.multiSelect
                          ? () => _toggleCategory(child)
                          : () => Navigator.of(
                              context,
                            ).pop(CategorySelectionResult(category: child)),
                    ),
              ],
            ),
          ),
      ],
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
    this.showSelectionControl = false,
    this.indent = 0,
  });

  final CategoryModel? category;
  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final bool selected;
  final bool showSelectionControl;
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
            if (showSelectionControl || selected)
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
