import 'package:flutter/foundation.dart';
import 'package:frontend/app/constants.dart';
import 'package:frontend/services/photo_api.dart';

class PhotoItem {
  final int photoId;
  final String imageUrl; // 모킹 시 로컬 파일 경로일 수 있음
  final String takenAt;
  final String location;
  final String brand;
  final List<String> tagList;
  final String? memo;
  final bool favorite;

  PhotoItem({
    required this.photoId,
    required this.imageUrl,
    required this.takenAt,
    required this.location,
    required this.brand,
    required this.tagList,
    this.memo,
    this.favorite = false,
  });
}

class PhotoProvider extends ChangeNotifier {
  final List<PhotoItem> _items = [];
  List<PhotoItem> get items => List.unmodifiable(_items);
  bool _loadedOnce = false;
  // Filters and pagination
  bool _favoriteOnly = false;
  String? _tagFilter;
  String _sort = 'takenAt,desc';
  int _page = 0;
  final int _size = 20;
  bool _isLoading = false;
  bool _hasMore = true;

  bool get favoriteOnly => _favoriteOnly;
  String? get tagFilter => _tagFilter;
  String get sort => _sort;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  PhotoProvider() {
    if (AppConstants.useMockApi) {
      _seedMockData();
    }
  }

  void add(PhotoItem item) {
    _items.insert(0, item);
    notifyListeners();
  }

  void addFromResponse(Map<String, dynamic> res) {
    add(
      PhotoItem(
        photoId: res['photoId'] as int,
        imageUrl: (res['imageUrl'] ?? '') as String,
        takenAt: res['takenAt'] as String? ?? '',
        location: res['location'] as String? ?? '',
        brand: res['brand'] as String? ?? '',
        tagList: (res['tagList'] as List?)?.cast<String>() ?? const [],
        memo: res['memo'] as String?,
        favorite: (res['favorite'] == true),
      ),
    );
  }

  void updateFromResponse(Map<String, dynamic> res) {
    final id = res['photoId'] as int;
    final idx = _items.indexWhere((e) => e.photoId == id);
    if (idx == -1) return;
    _items[idx] = PhotoItem(
      photoId: id,
      imageUrl: (res['imageUrl'] as String?) ?? _items[idx].imageUrl,
      takenAt: (res['takenAt'] as String?) ?? _items[idx].takenAt,
      location: (res['location'] as String?) ?? _items[idx].location,
      brand: (res['brand'] as String?) ?? _items[idx].brand,
      tagList: (res['tagList'] as List?)?.cast<String>() ?? _items[idx].tagList,
      memo: res['memo'] as String? ?? _items[idx].memo,
      favorite: res.containsKey('favorite')
          ? (res['favorite'] == true)
          : _items[idx].favorite,
    );
    notifyListeners();
  }

  void removeById(int photoId) {
    _items.removeWhere((e) => e.photoId == photoId);
    notifyListeners();
  }

  void _seedMockData() {
    if (_items.isNotEmpty) return;
    final List<PhotoItem> samples = [
      PhotoItem(
        photoId: 1001,
        imageUrl: 'https://picsum.photos/seed/nemo1/600/800',
        takenAt: '2025-05-03T14:12:00',
        location: '홍대 포토그레이',
        brand: '포토그레이',
        tagList: const ['친구', '추억'],
        memo: '첫 번째 더미',
        favorite: true,
      ),
      PhotoItem(
        photoId: 1002,
        imageUrl: 'https://picsum.photos/seed/nemo2/600/800',
        takenAt: '2025-05-18T19:40:00',
        location: '건대 인생네컷',
        brand: '인생네컷',
        tagList: const ['생일', '네컷'],
        memo: null,
        favorite: false,
      ),
      PhotoItem(
        photoId: 1003,
        imageUrl: 'https://picsum.photos/seed/nemo3/600/800',
        takenAt: '2025-06-01T11:05:00',
        location: '강남 포토이즘',
        brand: '포토이즘',
        tagList: const ['데이트'],
        memo: null,
        favorite: true,
      ),
      PhotoItem(
        photoId: 1004,
        imageUrl: 'https://picsum.photos/seed/nemo4/600/800',
        takenAt: '2025-06-10T20:22:00',
        location: '연남 포토그레이',
        brand: '포토그레이',
        tagList: const ['야간'],
        memo: null,
        favorite: false,
      ),
      PhotoItem(
        photoId: 1005,
        imageUrl: 'https://picsum.photos/seed/nemo5/600/800',
        takenAt: '2025-07-02T13:30:00',
        location: '부산 인생네컷',
        brand: '인생네컷',
        tagList: const ['여행'],
        memo: null,
        favorite: true,
      ),
      PhotoItem(
        photoId: 1006,
        imageUrl: 'https://picsum.photos/seed/nemo6/600/800',
        takenAt: '2025-07-15T16:18:00',
        location: '대구 포토이즘',
        brand: '포토이즘',
        tagList: const ['가족'],
        memo: null,
        favorite: false,
      ),
    ];
    _items.addAll(samples);
    notifyListeners();
  }

  void seedIfNeeded() {
    if (AppConstants.useMockApi && _items.isEmpty) {
      _seedMockData();
    }
  }

  Future<void> fetchListIfNeeded() async {
    if (AppConstants.useMockApi) return; // 실제 연동 시에만 호출
    if (_loadedOnce) return;
    _loadedOnce = true;
    await resetAndLoad();
  }

  Future<void> resetAndLoad({bool? favorite, String? tag, String? sort}) async {
    if (AppConstants.useMockApi) {
      // 모킹에선 초기 더미만 유지
      return;
    }
    _favoriteOnly = favorite ?? _favoriteOnly;
    _tagFilter = tag ?? _tagFilter;
    if (sort != null && sort.isNotEmpty) _sort = sort;
    _page = 0;
    _hasMore = true;
    _items.clear();
    notifyListeners();
    await loadNextPage();
  }

  Future<void> loadNextPage() async {
    if (AppConstants.useMockApi) return;
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();
    try {
      final api = PhotoApi();
      final list = await api.getPhotos(
        favorite: _favoriteOnly ? true : null,
        tag: _tagFilter,
        sort: _sort,
        page: _page,
        size: _size,
      );
      if (list.isEmpty) {
        _hasMore = false;
      } else {
        final existingIds = _items.map((e) => e.photoId).toSet();
        for (final m in list) {
          final id = m['photoId'] as int;
          if (existingIds.contains(id)) continue;
          _items.add(
            PhotoItem(
              photoId: id,
              imageUrl: (m['imageUrl'] ?? '') as String,
              takenAt: m['takenAt'] as String? ?? '',
              location: m['location'] as String? ?? '',
              brand: m['brand'] as String? ?? '',
              tagList: (m['tagList'] as List?)?.cast<String>() ?? const [],
              memo: m['memo'] as String?,
              favorite: (m['isFavorite'] == true) || (m['favorite'] == true),
            ),
          );
        }
        if (list.length < _size) {
          _hasMore = false;
        } else {
          _page += 1;
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
