import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/photo_provider.dart';

class SelectAlbumPhotosScreen extends StatefulWidget {
  const SelectAlbumPhotosScreen({super.key});

  @override
  State<SelectAlbumPhotosScreen> createState() =>
      _SelectAlbumPhotosScreenState();
}

class _SelectAlbumPhotosScreenState extends State<SelectAlbumPhotosScreen> {
  final Set<int> _selected = {};
  bool _onlyFavorite = false;
  String? _brand;
  String _sort = 'takenAt,desc';

  @override
  Widget build(BuildContext context) {
    final all = context.watch<PhotoProvider>().items;
    final filtered =
        all.where((p) {
          if (_onlyFavorite && !p.favorite) return false;
          if (_brand != null && _brand!.isNotEmpty && p.brand != _brand)
            return false;
          return true;
        }).toList()..sort((a, b) {
          switch (_sort) {
            case 'takenAt,asc':
              return a.takenAt.compareTo(b.takenAt);
            case 'brand,asc':
              return a.brand.compareTo(b.brand);
            case 'brand,desc':
              return b.brand.compareTo(a.brand);
            case 'takenAt,desc':
            default:
              return b.takenAt.compareTo(a.takenAt);
          }
        });
    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 선택'),
        actions: [
          IconButton(
            tooltip: '필터/정렬',
            icon: const Icon(Icons.tune),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _FilterSortSheet(
                  onlyFavorite: _onlyFavorite,
                  brand: _brand,
                  sort: _sort,
                  onChanged: (fav, brand, sort) {
                    setState(() {
                      _onlyFavorite = fav;
                      _brand = brand?.isEmpty == true ? null : brand;
                      _sort = sort;
                    });
                  },
                ),
              );
            },
          ),
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.toList()),
            child: const Text('완료'),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final p = filtered[i];
          final selected = _selected.contains(p.photoId);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _selected.remove(p.photoId);
                } else {
                  _selected.add(p.photoId);
                }
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Thumb(
                  imageUrl: p.imageUrl,
                  isFile:
                      p.imageUrl.isNotEmpty && !p.imageUrl.startsWith('http'),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: selected ? Colors.blue : Colors.black45,
                    child: Icon(
                      selected ? Icons.check : Icons.radio_button_unchecked,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 간단 썸네일 위젯 (PhotoListScreen의 _Thumb과 동일 인터페이스)
class _Thumb extends StatelessWidget {
  final String imageUrl;
  final bool isFile;
  const _Thumb({required this.imageUrl, required this.isFile});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const ColoredBox(color: Color(0xFFE0E0E0));
    }
    if (!isFile && Uri.tryParse(imageUrl)?.hasAbsolutePath == true) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFFE0E0E0)),
        loadingBuilder: (c, w, p) => p == null
            ? w
            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFE0E0E0)),
    );
  }
}

class _FilterSortSheet extends StatefulWidget {
  final bool onlyFavorite;
  final String? brand;
  final String sort;
  final void Function(bool fav, String? brand, String sort) onChanged;
  const _FilterSortSheet({
    required this.onlyFavorite,
    required this.brand,
    required this.sort,
    required this.onChanged,
  });

  @override
  State<_FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends State<_FilterSortSheet> {
  late bool _fav;
  String? _brand;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _fav = widget.onlyFavorite;
    _brand = widget.brand;
    _sort = widget.sort;
  }

  @override
  Widget build(BuildContext context) {
    final brands = <String?>['', '인생네컷', '포토그레이', '포토이즘'];
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '필터/정렬',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onChanged(_fav, _brand, _sort);
                    Navigator.pop(context);
                  },
                  child: const Text('적용'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('즐겨찾기만 보기'),
              trailing: IconButton(
                icon: Icon(
                  _fav ? Icons.favorite : Icons.favorite_border,
                  color: Colors.redAccent,
                ),
                onPressed: () => setState(() => _fav = !_fav),
              ),
              onTap: () => setState(() => _fav = !_fav),
            ),
            const SizedBox(height: 8),
            const Text('정렬'),
            RadioListTile<String>(
              title: const Text('최신순'),
              value: 'takenAt,desc',
              groupValue: _sort,
              onChanged: (v) => setState(() => _sort = v!),
            ),
            RadioListTile<String>(
              title: const Text('오래된순'),
              value: 'takenAt,asc',
              groupValue: _sort,
              onChanged: (v) => setState(() => _sort = v!),
            ),
            RadioListTile<String>(
              title: const Text('브랜드별로 보기'),
              value: 'brand,asc',
              groupValue: _sort,
              onChanged: (v) => setState(() => _sort = v!),
            ),
          ],
        ),
      ),
    );
  }
}
