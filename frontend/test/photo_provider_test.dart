import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/constants.dart';
import 'package:frontend/providers/photo_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppConstants.useMockApi = true;
  });

  tearDown(() {
    AppConstants.useMockApi = false;
  });

  group('PhotoProvider mock brand filter', () {
    test('brand filter can be cleared back to all items', () async {
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

