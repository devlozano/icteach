import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/admin/principal_archives_page.dart';

void main() {
  test('archives are grouped under descending school-year names', () {
    final groups = groupArchivedClassesByYear([
      {'name': 'Zulu', 'schoolYear': '2026-2027', 'status': 'archived'},
      {'name': 'Alpha', 'schoolYear': '2026-2027', 'status': 'archived'},
      {'name': 'Current', 'schoolYear': '2027-2028', 'status': 'active'},
      {'name': 'Later', 'schoolYear': '2027-2028', 'status': 'archived'},
    ]);

    expect(groups.keys, ['2027-2028', '2026-2027']);
    expect(groups['2026-2027']!.map((item) => item['name']), ['Alpha', 'Zulu']);
    expect(
      groups.values.expand((items) => items),
      isNot(contains(containsPair('name', 'Current'))),
    );
  });
}
