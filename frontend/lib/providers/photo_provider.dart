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
  // 모킹 모드에서 전체 원본 보관
  final List<PhotoItem> _allMockItems = [];
  static const Object _paramNotSet = Object();
  List<PhotoItem> get items => List.unmodifiable(_items);
  bool _loadedOnce = false;
  // Filters and pagination
  bool _favoriteOnly = false;
  String? _tagFilter;
  String? _brandFilter;
  String _sort = 'takenAt,desc';
  int _page = 0;
  final int _size = 20;
  bool _isLoading = false;
  bool _hasMore = true;

  bool get favoriteOnly => _favoriteOnly;
  String? get tagFilter => _tagFilter;
  String? get brandFilter => _brandFilter;
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
    if (AppConstants.useMockApi) {
      _allMockItems.insert(0, item);
    }
    notifyListeners();
  }

  void addFromResponse(Map<String, dynamic> res) {
    final photoId = res['photoId'] as int;
    // 이미 존재하는 사진인지 확인
    final existingIdx = _items.indexWhere((e) => e.photoId == photoId);
    if (existingIdx != -1) {
      // 이미 존재하면 업데이트만 수행
      updateFromResponse(res);
      return;
    }
    // 새 사진인 경우에만 추가
    add(
      PhotoItem(
        photoId: photoId,
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
    final mockIdx = _allMockItems.indexWhere((e) => e.photoId == id);
    if (idx == -1) return;

    // favorite 필드 업데이트: favorite 또는 isFavorite 중 하나라도 있으면 사용
    bool? newFavorite;
    if (res.containsKey('favorite')) {
      newFavorite = res['favorite'] == true;
    } else if (res.containsKey('isFavorite')) {
      newFavorite = res['isFavorite'] == true;
    }

    _items[idx] = PhotoItem(
      photoId: id,
      imageUrl: (res['imageUrl'] as String?) ?? _items[idx].imageUrl,
      takenAt: (res['takenAt'] as String?) ?? _items[idx].takenAt,
      location: (res['location'] as String?) ?? _items[idx].location,
      brand: (res['brand'] as String?) ?? _items[idx].brand,
      tagList: (res['tagList'] as List?)?.cast<String>() ?? _items[idx].tagList,
      memo: res['memo'] as String? ?? _items[idx].memo,
      favorite: newFavorite ?? _items[idx].favorite,
    );
    if (AppConstants.useMockApi && mockIdx != -1) {
      _allMockItems[mockIdx] = _items[idx];
    }
    notifyListeners();
  }

  void removeById(int photoId) {
    _items.removeWhere((e) => e.photoId == photoId);
    if (AppConstants.useMockApi) {
      _allMockItems.removeWhere((e) => e.photoId == photoId);
    }
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
    _allMockItems
      ..clear()
      ..addAll(samples);
    _items
      ..clear()
      ..addAll(samples);
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

  Future<void> resetAndLoad({
    Object? favorite = _paramNotSet,
    Object? tag = _paramNotSet,
    Object? brand = _paramNotSet,
    String? sort,
  }) async {
    debugPrint(
      '[PhotoProvider] resetAndLoad called with '
      'favorite=${favorite == _paramNotSet ? '(unchanged)' : favorite}, '
      'tag=${tag == _paramNotSet ? '(unchanged)' : tag}, '
      'brand=${brand == _paramNotSet ? '(unchanged)' : brand}, sort=$sort',
    );
    if (favorite != _paramNotSet) {
      _favoriteOnly = favorite == true;
    }
    if (tag != _paramNotSet) {
      _tagFilter = tag as String?;
    }
    if (brand != _paramNotSet) {
      _brandFilter = brand as String?;
    }
    if (sort != null && sort.isNotEmpty) {
      _sort = sort;
    }

    if (AppConstants.useMockApi) {
      // 모킹 모드: 로컬 필터/정렬 적용
      Iterable<PhotoItem> view = _allMockItems.isEmpty ? _items : _allMockItems;
      if (_brandFilter != null && _brandFilter!.isNotEmpty) {
        view = view.where((e) => e.brand == _brandFilter);
      }
      if (_tagFilter != null && _tagFilter!.isNotEmpty) {
        view = view.where((e) => e.tagList.contains(_tagFilter));
      }
      if (_favoriteOnly) {
        view = view.where((e) => e.favorite);
      }
      final list = view.toList();
      if (_sort == 'takenAt,asc') {
        list.sort((a, b) => a.takenAt.compareTo(b.takenAt));
      } else if (_sort == 'takenAt,desc') {
        list.sort((a, b) => b.takenAt.compareTo(a.takenAt));
      }
      debugPrint(
        '[PhotoProvider] mock mode applying filters '
        'favoriteOnly=$_favoriteOnly tag=$_tagFilter brand=$_brandFilter '
        'resultCount=${list.length} total=${_allMockItems.length}',
      );
      _items
        ..clear()
        ..addAll(list);
      notifyListeners();
      return;
    }
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
      final response = await api.getPhotos(
        favorite: _favoriteOnly ? true : null,
        tag: _tagFilter,
        brand: _brandFilter,
        sort: _sort,
        page: _page,
        size: _size,
      );
      // API 명세서: { content: [], page: {} } 구조
      final List content = (response['content'] as List?) ?? [];
      final pageInfo = response['page'] as Map<String, dynamic>?;
      if (content.isEmpty) {
        _hasMore = false;
      } else {
        final existingIds = _items.map((e) => e.photoId).toSet();
        for (final m in content) {
          final id = (m as Map)['photoId'] as int;
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
        // pageInfo에서 totalPages 확인하여 hasMore 결정
        if (pageInfo != null) {
          final currentPage = pageInfo['number'] as int? ?? _page;
          final totalPages = pageInfo['totalPages'] as int? ?? 1;
          _hasMore = currentPage < totalPages - 1;
          _page = currentPage + 1;
        } else {
          if (content.length < _size) {
            _hasMore = false;
          } else {
            _page += 1;
          }
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 로그인/로그아웃 시 상태 초기화
  void reset() {
    _items.clear();
    _allMockItems.clear();
    _loadedOnce = false;
    _favoriteOnly = false;
    _tagFilter = null;
    _brandFilter = null;
    _sort = 'takenAt,desc';
    _page = 0;
    _isLoading = false;
    _hasMore = true;
    notifyListeners();
  }
}
