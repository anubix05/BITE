import 'package:flutter_test/flutter_test.dart';
import 'package:bite/core/services/backup_service.dart';

void main() {
  test('ExportScope enum contains expected options', () {
    expect(ExportScope.values, contains(ExportScope.all));
    expect(ExportScope.values, contains(ExportScope.dateRange));
  });
}
