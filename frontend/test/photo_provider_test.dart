import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/constants.dart';
import 'package:frontend/providers/photo_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoProvider mock brand filter', () {
    test('brand filter can be cleared back to all items', () async {
      if (!AppConstants.useMockApi) {
        fail('Test requires AppConstants.useMockApi == true');
      }
      final provider = PhotoProvider();
      final totalCount = provider.items.length;
      expect(totalCount, greaterThan(0));

      // apply brand filter
      await provider.resetAndLoad(brand: '포토그레이');
      expect(provider.items.every((item) => item.brand == '포토그레이'), isTrue);
      final filteredCount = provider.items.length;
      expect(filteredCount, lessThan(totalCount));

      // clear brand filter
      await provider.resetAndLoad(brand: null);
      expect(provider.brandFilter, isNull);
      expect(provider.items.length, totalCount);
    });
  });
}

