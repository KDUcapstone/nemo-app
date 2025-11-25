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
  String _ownership = 'ALL'; // ALL, OWNED, SHARED
  final Set<int> _favoritedAlbumIds = <int>{};
  // 내가 공유 중/공유받은 앨범 ID 집합과 역할 맵
  final Set<int> _sharedAlbumIds = <int>{};
  final Map<int, String> _albumIdToMyRole =
      <int, String>{}; // OWNER|CO_OWNER|EDITOR|VIEWER

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get sort => _sort;
  bool get favoriteOnly => _favoriteOnly;
  String get ownership => _ownership;
  bool isFavorited(int albumId) => _favoritedAlbumIds.contains(albumId);
  bool isShared(int albumId) => _sharedAlbumIds.contains(albumId);
  String? myRoleOf(int albumId) => _albumIdToMyRole[albumId];

  Future<void> refreshSharedAlbums() async {
    try {
      final shared = await AlbumApi.getSharedAlbums(page: 0, size: 200);
      _sharedAlbumIds
        ..clear()
        ..addAll(shared.map<int>((e) => (e['albumId'] as int)));
      _albumIdToMyRole
        ..clear()
        ..addEntries(
          shared.map(
            (e) => MapEntry(
              e['albumId'] as int,
              (e['role']?.toString() ?? 'VIEWER')
                  .toUpperCase(), // myRole → role
            ),
          ),
        );
      notifyListeners();
    } catch (_) {
      // 무시
    }
  }

  void setFavorite(int albumId, bool favorited) {
    if (favorited) {
      _favoritedAlbumIds.add(albumId);
    } else {
      _favoritedAlbumIds.remove(albumId);
    }
    notifyListeners();
  }

  void addFromResponse(Map<String, dynamic> res) {
    final albumId = res['albumId'] as int;

    // photoIdList 파싱 (Long → int 변환 처리)
    List<int> photoIdList = [];
    if (res['photoIdList'] != null) {
      try {
        final list = res['photoIdList'] as List;
        photoIdList = list.map((e) => (e as num).toInt()).toList();
      } catch (e) {
        // 파싱 실패 시 photoList에서 추출 시도
        if (res['photoList'] != null) {
          final photoList = res['photoList'] as List;
          photoIdList = photoList
              .map((p) {
                try {
                  return (p as Map)['photoId'] as num?;
                } catch (_) {
                  return null;
                }
              })
              .whereType<num>()
              .map((e) => e.toInt())
              .toList();
        }
      }
    } else if (res['photoList'] != null) {
      // photoIdList가 없으면 photoList에서 추출
      final photoList = res['photoList'] as List;
      photoIdList = photoList
          .map((p) {
            try {
              return (p as Map)['photoId'] as num?;
            } catch (_) {
              return null;
            }
          })
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();
    }

    final photoCount = (res['photoCount'] as int?) ?? photoIdList.length;

    // 이미 존재하는 앨범인지 확인
    final existingIdx = _albums.indexWhere((e) => e.albumId == albumId);
    if (existingIdx != -1) {
      // 이미 존재하면 업데이트만 수행
      _albums[existingIdx] = AlbumItem(
        albumId: albumId,
        title: (res['title'] ?? '') as String,
        description: (res['description'] ?? '') as String,
        coverPhotoUrl: res['coverPhotoUrl'] as String?,
        photoCount: photoCount,
        createdAt: (res['createdAt'] as String?) ?? '',
        photoIdList: photoIdList,
      );
      notifyListeners();
      return;
    }
    // 새 앨범인 경우에만 추가
    final item = AlbumItem(
      albumId: albumId,
      title: (res['title'] ?? '') as String,
      description: (res['description'] ?? '') as String,
      coverPhotoUrl: res['coverPhotoUrl'] as String?,
      photoCount: photoCount,
      createdAt: (res['createdAt'] as String?) ?? '',
      photoIdList: photoIdList,
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

  void updateMeta({required int albumId, String? title, String? description}) {
    final idx = _albums.indexWhere((e) => e.albumId == albumId);
    if (idx == -1) return;
    _albums[idx] = _albums[idx].copyWith(
      title: title,
      description: description,
    );
    notifyListeners();
  }

  void removeAlbum(int albumId) {
    _albums.removeWhere((e) => e.albumId == albumId);
    notifyListeners();
  }

  Future<void> loadDetail(int albumId) async {
    try {
      final res = await AlbumApi.getAlbum(albumId);
      final idx = _albums.indexWhere((e) => e.albumId == albumId);
      final existing = idx != -1 ? _albums[idx] : null;

      // photoIdList 파싱 (Long → int 변환 처리)
      List<int> photoIdList = [];
      if (res['photoIdList'] != null) {
        try {
          final list = res['photoIdList'] as List;
          photoIdList = list.map((e) => (e as num).toInt()).toList();
        } catch (e) {
          // 파싱 실패 시 photoList에서 추출 시도
          if (res['photoList'] != null) {
            final photoList = res['photoList'] as List;
            photoIdList = photoList
                .map((p) {
                  try {
                    return (p as Map)['photoId'] as num?;
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<num>()
                .map((e) => e.toInt())
                .toList();
          }
        }
      } else if (res['photoList'] != null) {
        // photoIdList가 없으면 photoList에서 추출
        final photoList = res['photoList'] as List;
        photoIdList = photoList
            .map((p) {
              try {
                return (p as Map)['photoId'] as num?;
              } catch (_) {
                return null;
              }
            })
            .whereType<num>()
            .map((e) => e.toInt())
            .toList();
      }

      final photoCount =
          (res['photoCount'] as int?) ??
          existing?.photoCount ??
          photoIdList.length;

      final item = AlbumItem(
        albumId: albumId,
        // 모킹/서버 응답이 부정확한 경우 기존 값을 우선 유지
        title: (existing?.title.isNotEmpty == true)
            ? existing!.title
            : ((res['title'] ?? '') as String),
        description: (existing?.description.isNotEmpty == true)
            ? existing!.description
            : ((res['description'] ?? '') as String),
        coverPhotoUrl: res['coverPhotoUrl'] as String?,
        photoCount: photoCount,
        createdAt: (res['createdAt'] as String?) ?? '',
        photoIdList: photoIdList,
      );
      if (idx == -1) {
        _albums.add(item);
      } else {
        _albums[idx] = item;
      }
      notifyListeners();
    } catch (e) {
      // 에러 처리: 로그만 출력하고 무한 로딩 방지
      debugPrint('앨범 상세 조회 실패 (albumId: $albumId): $e');
      // 에러 발생 시에도 기존 앨범 정보는 유지
    }
  }

  Future<void> resetAndLoad({
    String? sort,
    bool? favoriteOnly,
    String? ownership,
  }) async {
    if (AppConstants.useMockApi) {
      // 모킹에선 서버 호출 대신 getAlbums 모킹을 그대로 사용
    }
    _sort = sort ?? _sort;
    _favoriteOnly = favoriteOnly ?? _favoriteOnly;
    _ownership = ownership ?? _ownership;
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
        ownership: _ownership,
      );
      final List content = (res['content'] as List? ?? []);
      if (content.isEmpty) {
        _hasMore = false;
      } else {
        // 중복 체크 추가
        final existingIds = _albums.map((e) => e.albumId).toSet();
        for (final m in content) {
          final map = (m as Map).cast<String, dynamic>();
          final albumId = map['albumId'] as int;
          // 이미 존재하는 앨범은 건너뛰기
          if (existingIds.contains(albumId)) continue;
          _albums.add(
            AlbumItem(
              albumId: albumId,
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
