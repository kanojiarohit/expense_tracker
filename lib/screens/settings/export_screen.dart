import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/category.dart';
import '../../navigation/app_route.dart';
import '../../services/export_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../categories/select_category_screen.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ExportService _exportService = ExportService();
  DateTime? _fromMonth;
  DateTime? _toMonth;
  List<CategoryModel> _selectedCategories = [];
  bool _exporting = false;

  Future<void> _pickMonth({required bool isFrom}) async {
    final current = isFrom ? _fromMonth : _toMonth;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year, now.month),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isFrom ? 'Choose From Month' : 'Choose To Month',
    );
    if (picked == null || !mounted) {
      return;
    }
    final month = DateTime(picked.year, picked.month);
    setState(() {
      if (isFrom) {
        _fromMonth = month;
        if (_toMonth != null && _toMonth!.isBefore(_fromMonth!)) {
          _toMonth = _fromMonth;
        }
      } else {
        _toMonth = month;
        if (_fromMonth != null && _fromMonth!.isAfter(_toMonth!)) {
          _fromMonth = _toMonth;
        }
      }
    });
  }

  Future<void> _pickCategories() async {
    final result = await Navigator.of(context).push<CategorySelectionResult>(
      AppRoute(
        builder: (_) => SelectCategoryScreen(
          selectedCategoryIds: _selectedCategories
              .map((item) => item.id)
              .toSet(),
          multiSelect: true,
          showAddButton: false,
          title: 'Select Categories',
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      if (result.cleared) {
        _selectedCategories = [];
      } else if (result.categories != null) {
        _selectedCategories = result.categories!;
      }
    });
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final result = await _exportService.exportCsv(
        fromMonth: _fromMonth,
        toMonth: _toMonth,
        categoryIds: _selectedCategories.map((item) => item.id).toSet(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${result.recordCount} records to ${result.filePath}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              borderRadius: 8,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                children: [
                  _FilterTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'From month',
                    value: _fromMonth == null
                        ? 'Any start'
                        : monthLabel(_fromMonth!),
                    onTap: () => _pickMonth(isFrom: true),
                    onClear: _fromMonth == null
                        ? null
                        : () => setState(() => _fromMonth = null),
                  ),
                  const Divider(height: 1),
                  _FilterTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'To month',
                    value: _toMonth == null ? 'Any end' : monthLabel(_toMonth!),
                    onTap: () => _pickMonth(isFrom: false),
                    onClear: _toMonth == null
                        ? null
                        : () => setState(() => _toMonth = null),
                  ),
                  const Divider(height: 1),
                  _CategoryFilterTile(
                    categories: _selectedCategories,
                    onTap: _pickCategories,
                    onClear: _selectedCategories.isEmpty
                        ? null
                        : () => setState(() => _selectedCategories = []),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Export transactions',
                      icon: Icons.file_download_outlined,
                      isLoading: _exporting,
                      onPressed: _export,
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

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear',
              )
            else
              Icon(Icons.chevron_right_rounded, color: mutedColor),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterTile extends StatelessWidget {
  const _CategoryFilterTile({
    required this.categories,
    required this.onTap,
    this.onClear,
  });

  final List<CategoryModel> categories;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.category_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _categoryValue,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear',
              )
            else
              Icon(Icons.chevron_right_rounded, color: mutedColor),
          ],
        ),
      ),
    );
  }

  String get _categoryValue {
    if (categories.isEmpty) {
      return 'All categories';
    }
    if (categories.length == 1) {
      return categories.first.name;
    }
    if (categories.length == 2) {
      return '${categories[0].name}, ${categories[1].name}';
    }
    return '${categories.length} categories selected';
  }
}
