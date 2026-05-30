import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    super.key,
    required this.reloadToken,
    required this.onAddCategory,
    required this.onEditCategory,
  });

  final int reloadToken;
  final VoidCallback onAddCategory;
  final ValueChanged<CategoryModel> onEditCategory;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (label: 'Expense', type: CategoryTypes.expense),
    (label: 'Income', type: CategoryTypes.income),
    (label: 'Debt/Loan', type: CategoryTypes.debtLoan),
  ];

  final CategoryService _categoryService = CategoryService();
  late final TabController _tabController;
  bool _loading = true;
  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(() => setState(() {}));
    _load();
  }

  @override
  void didUpdateWidget(covariant CategoriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final categories = await _categoryService.fetchAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = _tabs[_tabController.index].type;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeader(
                        title: 'Categories',
                        subtitle: 'Parent and child categories',
                      ),
                    ),
                    if (selectedType != CategoryTypes.debtLoan)
                      IconButton.filled(
                        onPressed: widget.onAddCategory,
                        icon: const Icon(Icons.add),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  tabs: [for (final tab in _tabs) Tab(text: tab.label)],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      for (final tab in _tabs)
                        _CategoryTabBody(
                          type: tab.type,
                          categories: _categories,
                          onEditCategory: widget.onEditCategory,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTabBody extends StatelessWidget {
  const _CategoryTabBody({
    required this.type,
    required this.categories,
    required this.onEditCategory,
  });

  final String type;
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onEditCategory;

  @override
  Widget build(BuildContext context) {
    final items = categories.where((item) => item.type == type).toList();
    final roots = items.where((item) => item.parentCategoryId == null).toList();

    if (roots.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: const [
          AppCard(
            borderRadius: 8,
            child: EmptyState(
              title: 'No categories found',
              description: 'Default categories should appear here after setup.',
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final root in roots)
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            borderRadius: 8,
            child: Column(
              children: [
                _CategoryRow(
                  category: root,
                  onTap: root.isSystem ? null : () => onEditCategory(root),
                ),
                for (final child in items.where(
                  (item) => item.parentCategoryId == root.id,
                ))
                  _CategoryRow(
                    category: child,
                    onTap: child.isSystem ? null : () => onEditCategory(child),
                    indent: 28,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, this.onTap, this.indent = 0});

  final CategoryModel category;
  final VoidCallback? onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(indent, 8, 0, 8),
        child: Row(
          children: [
            CategoryAvatar(category: category),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (!category.isSystem) const Icon(Icons.edit_outlined, size: 20),
          ],
        ),
      ),
    );
  }
}
