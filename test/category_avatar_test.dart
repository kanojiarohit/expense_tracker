import 'package:expense_tracker/widgets/category_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category initials stay distinct for similar names', () {
    expect(categoryInitials('Food'), 'FO');
    expect(categoryInitials('Fuel'), 'FU');
    expect(categoryInitials('Freelance'), 'FR');
  });

  test('category initials use first letters for multi word names', () {
    expect(categoryInitials('School Fees'), 'SF');
    expect(categoryInitials('House Rent'), 'HR');
  });
}
