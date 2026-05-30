String? requiredValidator(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label is required';
  }
  return null;
}

String? positiveAmountValidator(String? value) {
  final clean = value?.replaceAll(',', '').trim() ?? '';
  final parsed = double.tryParse(clean);
  if (parsed == null || parsed <= 0) {
    return 'Enter a valid amount';
  }
  return null;
}
