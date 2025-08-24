import 'package:flutter/foundation.dart';
import 'package:frontend/app/constants.dart';
import 'package:frontend/services/album_api.dart';

class AlbumItem {
  final int albumId;
  final String title;
  final String description;
  final String? coverPhotoUrl;
  final int photoCount;
  final String createdAt;
  final List<int> photoIdList;

  const AlbumItem({
    required this.albumId,
    required this.title,
    required this.description,
    required this.coverPhotoUrl,
    required this.photoCount,
    required this.createdAt,
    required this.photoIdList,
  });

  AlbumItem copyWith({
    String? title,
    String? description,
    String? coverPhotoUrl,
    int? photoCount,
    List<int>? photoIdList,
  }) {
    return AlbumItem(
      albumId: albumId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      photoCount: photoCount ?? this.photoCount,
      createdAt: createdAt,
      photoIdList: photoIdList ?? this.photoIdList,
    );
  }
}

class AlbumProvider extends ChangeNotifier {
  final List<AlbumItem> _albums = [];
  List<AlbumItem> get albums => List.unmodifiable(_albums);
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _size = 10;
  String _sort = 'createdAt,desc';
  bool _favoriteOnly = false;

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get sort => _sort;
  bool get favoriteOnly => _favoriteOnly;

  void addFromResponse(Map<String, dynamic> res) {
    final item = AlbumItem(
      albumId: res['albumId'] as int,
      title: (res['title'] ?? '') as String,
      description: (res['description'] ?? '') as String,
      coverPhotoUrl: res['coverPhotoUrl'] as String?,
      photoCount:
          (res['photoCount'] as int?) ??
          (res['photoIdList'] as List?)?.length ??
          0,
      createdAt: (res['createdAt'] as String?) ?? '',
      photoIdList: ((res['photoIdList'] as List?)?.cast<int>()) ?? const [],
    );
    _albums.insert(0, item);
    notifyListeners();
  }

  AlbumItem? byId(int albumId) {
    try {
      return _albums.firstWhere((e) => e.albumId == albumId);
    } catch (_) {
      return null;
    }
  }

  void addPhotos(int albumId, List<int> photoIds) {
    final idx = _albums.indexWhere((e) => e.albumId == albumId);
    if (idx == -1) return;
    final set = {..._albums[idx].photoIdList, ...photoIds};
    _albums[idx] = _albums[idx].copyWith(
      photoIdList: set.toList(),
      photoCount: set.length,
    );
    notifyListeners();
  }

  void removePhotos(int albumId, List<int> photoIds) {
    final idx = _albums.indexWhere((e) => e.albumId == albumId);
    if (idx == -1) return;
    final set = {..._albums[idx].photoIdList}..removeAll(photoIds);
    _albums[idx] = _albums[idx].copyWith(
      photoIdList: set.toList(),
      photoCount: set.length,
    );
    notifyListeners();
  }

  void updateCoverUrl(int albumId, String? coverUrl) {
    final idx = _albums.indexWhere((e) => e.albumId == albumId);
    if (idx == -1) return;
    _albums[idx] = _albums[idx].copyWith(coverPhotoUrl: coverUrl);
    notifyListeners();
  }

  void removeAlbum(int albumId) {
    _albums.removeWhere((e) => e.albumId == albumId);
    notifyListeners();
  }

  Future<void> loadDetail(int albumId) async {
    final res = await AlbumApi.getAlbum(albumId);
    final idx = _albums.indexWhere((e) => e.albumId == albumId);
    final item = AlbumItem(
      albumId: albumId,
      title: (res['title'] ?? '') as String,
      description: (res['description'] ?? '') as String,
      coverPhotoUrl: res['coverPhotoUrl'] as String?,
      photoCount:
          (res['photoCount'] as int?) ??
          (res['photoIdList'] as List?)?.length ??
          0,
      createdAt: (res['createdAt'] as String?) ?? '',
      photoIdList: ((res['photoIdList'] as List?)?.cast<int>()) ?? const [],
    );
    if (idx == -1) {
      _albums.add(item);
    } else {
      _albums[idx] = item;
    }
    notifyListeners();
  }

  Future<void> resetAndLoad({String? sort, bool? favoriteOnly}) async {
    if (AppConstants.useMockApi) {
      // 모킹에선 서버 호출 대신 getAlbums 모킹을 그대로 사용
    }
    _sort = sort ?? _sort;
    _favoriteOnly = favoriteOnly ?? _favoriteOnly;
    _albums.clear();
    _page = 0;
    _hasMore = true;
    notifyListeners();
    await loadNextPage();
  }

  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();
    try {
      final res = await AlbumApi.getAlbums(
        sort: _sort,
        page: _page,
        size: _size,
        favoriteOnly: _favoriteOnly ? true : null,
      );
      final List content = (res['content'] as List? ?? []);
      if (content.isEmpty) {
        _hasMore = false;
      } else {
        for (final m in content) {
          final map = (m as Map).cast<String, dynamic>();
          _albums.add(
            AlbumItem(
              albumId: map['albumId'] as int,
              title: (map['title'] ?? '') as String,
              description: (map['description'] ?? '') as String,
              coverPhotoUrl: map['coverPhotoUrl'] as String?,
              photoCount: (map['photoCount'] as int?) ?? 0,
              createdAt: (map['createdAt'] as String?) ?? '',
              photoIdList: const [],
            ),
          );
        }
        if (content.length < _size) {
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
