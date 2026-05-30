import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../models/category.dart';
import '../../navigation/app_route.dart';
import '../../services/category_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'select_category_screen.dart';

class AddEditCategoryScreen extends StatefulWidget {
  const AddEditCategoryScreen({
    super.key,
    this.category,
    this.initialType,
    this.lockType = false,
  });

  final CategoryModel? category;
  final String? initialType;
  final bool lockType;

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _parentController = TextEditingController();
  final CategoryService _categoryService = CategoryService();

  bool _saving = false;
  String _type = CategoryTypes.expense;
  String _colorHex = categoryColorChoices.first;
  int? _parentCategoryId;
  List<CategoryModel> _categories = [];

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    if (category != null) {
      _nameController.text = category.name;
      _type = category.type;
      _colorHex = category.colorHex;
      _parentCategoryId = category.parentCategoryId;
    } else if (widget.initialType != null) {
      _type = widget.initialType!;
    }
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final categories = await _categoryService.fetchAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
      _syncParentText();
    });
  }

  void _syncParentText() {
    final parent = _categories
        .where((category) => category.id == _parentCategoryId)
        .cast<CategoryModel?>()
        .firstWhere((_) => true, orElse: () => null);
    _parentController.text = parent?.name ?? 'No parent';
  }

  Future<void> _openParentPicker() async {
    final result = await Navigator.of(context).push<CategorySelectionResult>(
      AppRoute(
        builder: (_) => SelectCategoryScreen(
          type: _type,
          selectedCategoryId: _parentCategoryId,
          parentOnly: true,
          includeNoParent: true,
          excludedCategoryId: widget.category?.id,
          showAddButton: false,
          title: 'Select Parent',
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _parentCategoryId = result.cleared ? null : result.category?.id;
      _syncParentText();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final category = widget.category ?? CategoryModel();
      category
        ..name = _nameController.text.trim()
        ..type = _type
        ..icon = widget.category?.icon ?? categoryIconChoices.first
        ..colorHex = _colorHex
        ..parentCategoryId = _parentCategoryId
        ..isSystem = widget.category?.isSystem ?? false
        ..createdAt = widget.category?.createdAt ?? DateTime.now();
      await _categoryService.save(category);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.category == null) {
      return;
    }
    try {
      await _categoryService.delete(widget.category!);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
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
        title: Text(_isEditing ? 'Edit Category' : 'Add Category'),
        actions: [
          if (_isEditing && !(widget.category?.isSystem ?? false))
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Category name',
                validator: (value) => requiredValidator(value, 'Category name'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Category type',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: CategoryTypes.expense,
                    child: Text('Expense'),
                  ),
                  DropdownMenuItem(
                    value: CategoryTypes.income,
                    child: Text('Income'),
                  ),
                  DropdownMenuItem(
                    value: CategoryTypes.debtLoan,
                    child: Text('Debt/Loan'),
                  ),
                ],
                onChanged: widget.lockType
                    ? null
                    : (value) => setState(() {
                        _type = value ?? CategoryTypes.expense;
                        _parentCategoryId = null;
                        _syncParentText();
                      }),
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _parentController,
                label: 'Parent category',
                readOnly: true,
                onTap: _openParentPicker,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: _isEditing ? 'Save Changes' : 'Save Category',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
