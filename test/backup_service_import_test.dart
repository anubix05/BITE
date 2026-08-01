import 'package:flutter_test/flutter_test.dart';
import 'package:bite/core/services/backup_service.dart';

void main() {
  test('ImportOptions properties test', () {
    const opts = ImportOptions(importMeals: true, importSettings: false);
    expect(opts.importMeals, isTrue);
    expect(opts.importSettings, isFalse);

    const opts2 = ImportOptions(importMeals: false, importSettings: true);
    expect(opts2.importMeals, isFalse);
    expect(opts2.importSettings, isTrue);
  });
}
