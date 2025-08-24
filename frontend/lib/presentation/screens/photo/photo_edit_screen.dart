import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/photo_api.dart';
import 'package:frontend/providers/photo_provider.dart';

class PhotoEditScreen extends StatefulWidget {
  final int photoId;
  const PhotoEditScreen({super.key, required this.photoId});

  @override
  State<PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends State<PhotoEditScreen> {
  bool _loading = true;
  bool _saving = false;
  final _tagController = TextEditingController();
  final _memoController = TextEditingController();
  List<String> _tags = [];
  List<String> _friendNames = [];
  bool _isFavorite = false;

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
      _memoController.text = (res['memo'] as String?) ?? '';
      final friends = (res['friendList'] as List?) ?? const [];
      _friendNames = friends
          .whereType<Map>()
          .map((e) => (e['nickname'] as String?) ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      _isFavorite = (res['isFavorite'] == true) || (res['favorite'] == true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('편집 데이터 로드 실패: $e')));
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = PhotoApi();
      final res = await api.updatePhoto(
        widget.photoId,
        tagList: _tags,
        memo: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
        // friendIdList: 추후 닉네임→ID 매핑 완료 후 전송
        isFavorite: _isFavorite,
      );
      if (!mounted) return;
      context.read<PhotoProvider>().updateFromResponse({
        'photoId': widget.photoId,
        'tagList': res['tagList'] ?? _tags,
        'memo': res['memo'],
        'favorite': res['isFavorite'] ?? res['favorite'],
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장 완료')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('상세 편집'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          top: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('태그'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(hintText: '태그 입력 후 엔터'),
                    onSubmitted: (v) {
                      final t = v.trim();
                      if (t.isEmpty) return;
                      setState(() => _tags = [..._tags, t]);
                      _tagController.clear();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _tags
                  .map(
                    (t) => Chip(
                      label: Text(t),
                      onDeleted: () => setState(
                        () => _tags = _tags.where((e) => e != t).toList(),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '메모(선택)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('즐겨찾기'),
                const SizedBox(width: 12),
                Switch(
                  value: _isFavorite,
                  onChanged: (v) => setState(() => _isFavorite = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('함께한 친구: ${_friendNames.join(', ')}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      setState(() => _friendNames = [..._friendNames, '네컷러버']),
                  child: const Text('+ 네컷러버'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      setState(() => _friendNames = [..._friendNames, '사진장인']),
                  child: const Text('+ 사진장인'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _friendNames = []),
                  child: const Text('초기화'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
