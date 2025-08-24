import 'dart:io';
import 'package:flutter/material.dart';

import 'package:frontend/services/photo_api.dart';

class PhotoDetailScreen extends StatefulWidget {
  final int photoId;
  const PhotoDetailScreen({super.key, required this.photoId});

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  bool _loading = true;
  List<String> _tags = [];
  String? _memo;
  String _imageUrl = '';
  String _location = '';
  String _brand = '';
  DateTime? _takenAt;
  List<Map<String, dynamic>> _friendList = const [];
  Map<String, dynamic>? _owner;

  final _tagController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = PhotoApi();
      final res = await api.getPhoto(widget.photoId);
      _imageUrl = (res['imageUrl'] ?? '') as String;
      _tags = (res['tagList'] as List?)?.cast<String>() ?? [];
      _memo = res['memo'] as String?;
      _memoController.text = _memo ?? '';
      _location = (res['location'] as String?) ?? '';
      _brand = (res['brand'] as String?) ?? '';
      final t = res['takenAt'] as String?;
      _takenAt = t != null ? DateTime.tryParse(t) : null;
      _friendList = ((res['friendList'] as List?) ?? const [])
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final o = res['owner'];
      _owner = (o is Map) ? o.cast<String, dynamic>() : null;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상세 조회 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    Widget _buildImage() {
      if (_imageUrl.isEmpty) {
        return const _DetailFallback();
      }
      final uri = Uri.tryParse(_imageUrl);
      final isFile = uri == null || !uri.hasScheme;
      if (isFile) {
        final f = File(_imageUrl);
        if (!f.existsSync()) return const _DetailFallback();
        return Image.file(
          f,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const _DetailFallback(),
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
        );
      } else {
        return Image.network(
          _imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (c, child, p) => p == null
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (c, e, s) => const _DetailFallback(),
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('사진 상세')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Container(
                        color: Colors.black12,
                        child: _buildImage(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _tags
                            .map((t) => Chip(label: Text(t)))
                            .toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        (_memoController.text.isEmpty
                                ? ''
                                : _memoController.text)
                            .toString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_friendList.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          height: 56,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (_, i) {
                              final f = _friendList[i];
                              final url = f['profileImageUrl'] as String?;
                              return Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: url != null
                                        ? NetworkImage(url)
                                        : null,
                                    child: url == null
                                        ? const Icon(Icons.person_outline)
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(f['nickname']?.toString() ?? ''),
                                ],
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemCount: _friendList.length,
                          ),
                        ),
                      ),
                    if (_owner != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage:
                                  (_owner!['profileImageUrl'] as String?) !=
                                      null
                                  ? NetworkImage(
                                      _owner!['profileImageUrl'] as String,
                                    )
                                  : null,
                              child:
                                  (_owner!['profileImageUrl'] as String?) ==
                                      null
                                  ? const Icon(Icons.person_outline)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text('소유자: ${_owner!['nickname']}'),
                          ],
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text('촬영 위치: $_location')),
                          const SizedBox(width: 8),
                          Expanded(child: Text('브랜드: $_brand')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '촬영 시각: ${_takenAt?.toIso8601String() ?? ''}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailFallback extends StatelessWidget {
  const _DetailFallback();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_outlined, size: 42, color: Colors.grey),
    );
  }
}

class PhotoDetailSheet extends StatefulWidget {
  final int photoId;
  const PhotoDetailSheet({super.key, required this.photoId});

  @override
  State<PhotoDetailSheet> createState() => _PhotoDetailSheetState();
}

class DetailSheetModal extends StatelessWidget {
  final int photoId;
  const DetailSheetModal({super.key, required this.photoId});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox.shrink(),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: PhotoDetailSheet(photoId: photoId),
        ),
      ],
    );
  }
}

class _PhotoDetailSheetState extends State<PhotoDetailSheet> {
  bool _loading = true;
  List<String> _tags = [];
  String? _memo;
  String _location = '';
  String _brand = '';
  DateTime? _takenAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = PhotoApi();
      final res = await api.getPhoto(widget.photoId);
      _tags = (res['tagList'] as List?)?.cast<String>() ?? [];
      _memo = res['memo'] as String?;
      _location = (res['location'] as String?) ?? '';
      _brand = (res['brand'] as String?) ?? '';
      final t = res['takenAt'] as String?;
      _takenAt = t != null ? DateTime.tryParse(t) : null;
    } catch (_) {
      // 무시하고 로딩 종료
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _tags
                            .map((t) => Chip(label: Text(t)))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      if ((_memo ?? '').isNotEmpty)
                        Text(
                          _memo!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 12),
                      Text('촬영 위치: $_location'),
                      const SizedBox(height: 8),
                      Text('브랜드: $_brand'),
                      const SizedBox(height: 8),
                      Text('촬영 시각: ${_takenAt?.toIso8601String() ?? ''}'),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
