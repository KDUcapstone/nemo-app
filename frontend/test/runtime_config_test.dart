import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/constants.dart';

void main() {
  test('real backend is used unless mock mode is explicitly enabled', () {
    expect(AppConstants.useMockApi, isFalse);
  });
}
