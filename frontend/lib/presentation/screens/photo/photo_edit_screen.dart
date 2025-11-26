import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/photo_api.dart';
import 'package:frontend/services/friend_api.dart';
import 'package:frontend/providers/photo_provider.dart';

class PhotoEditScreen extends StatefulWidget {
  final int photoId;
  const PhotoEditScreen({super.key, required this.photoId});

  @override
  State<PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends State<PhotoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  DateTime? _takenAt;
  List<String> _tags = [];
  Set<int> _selectedFriendIds = {};
  bool _loadingFriends = false;
  List<Map<String, dynamic>> _friends = [];
  String _imageUrl = '';
  // 브랜드 선택 옵션 (드롭다운 + 직접 입력)
  final List<String> _brandOptions = const [
    '직접 입력',
    '인생네컷',
    '포토이즘',
    '하루필름',
    '포토그레이',
    '포토랩',
  ];
  String _selectedBrand = '직접 입력';

  @override
  void initState() {
    super.initState();
    _load();
    _loadFriends();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = PhotoApi();
      final res = await api.getPhoto(widget.photoId);
      _imageUrl = (res['imageUrl'] ?? '') as String;
      _locationCtrl.text = (res['location'] as String?) ?? '';
      _brandCtrl.text = (res['brand'] as String?) ?? '';
      _tags = (res['tagList'] as List?)?.cast<String>() ?? [];
      _memoCtrl.text = (res['memo'] as String?) ?? '';
      // 초기 브랜드를 옵션에 맞게 선택 상태로 설정
      final currentBrand = _brandCtrl.text.trim();
      if (currentBrand.isNotEmpty && _brandOptions.contains(currentBrand)) {
        _selectedBrand = currentBrand;
      } else {
        _selectedBrand = '직접 입력';
      }

      // 촬영일시 파싱
      final t = res['takenAt'] as String?;
      _takenAt = t != null ? DateTime.tryParse(t) : null;

      // 친구 목록에서 ID 추출
      final friends = (res['friendList'] as List?) ?? const [];
      _selectedFriendIds = friends
          .whereType<Map>()
          .map((e) => e['userId'] as int?)
          .whereType<int>()
          .toSet();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('편집 데이터 로드 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _loadingFriends = true);
    try {
      final friends = await FriendApi.getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _loadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingFriends = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('친구 목록 로드 실패: $e')));
      }
    }
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _brandCtrl.dispose();
    _memoCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectTakenAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _takenAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        // 날짜만 선택, 시간은 00:00:00으로 설정
        _takenAt = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _showFriendPicker() async {
    final selected = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final currentSelected = Set<int>.from(_selectedFriendIds);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '친구 선택',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, currentSelected),
                              child: const Text('완료'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: _friends.length,
                          itemBuilder: (_, i) {
                            final f = _friends[i];
                            final id = f['userId'] as int;
                            final nick = f['nickname'] as String? ?? '친구$id';
                            final avatarUrl =
                                (f['profileImageUrl'] ?? f['avatarUrl'])
                                    as String?;
                            final checked = currentSelected.contains(id);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null || avatarUrl.isEmpty
                                    ? const Icon(Icons.person_outline)
                                    : null,
                              ),
                              title: Text(nick),
                              trailing: Checkbox(
                                value: checked,
                                onChanged: (v) {
                                  setModalState(() {
                                    if (v == true) {
                                      currentSelected.add(id);
                                    } else {
                                      currentSelected.remove(id);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setModalState(() {
                                  if (checked) {
                                    currentSelected.remove(id);
                                  } else {
                                    currentSelected.add(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedFriendIds = selected;
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _saving = true);
    try {
      final api = PhotoApi();
      final res = await api.updatePhotoDetails(
        widget.photoId,
        takenAt: _takenAt,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        tagList: _tags.isEmpty ? null : _tags,
        friendIdList: _selectedFriendIds.isEmpty
            ? null
            : _selectedFriendIds.toList(),
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      );
      if (!mounted) return;

      // PhotoProvider 업데이트
      context.read<PhotoProvider>().updateFromResponse({
        'photoId': widget.photoId,
        'takenAt': res['takenAt'],
        'location': res['location'],
        'brand': res['brand'],
        'tagList': res['tagList'] ?? _tags,
        'memo': res['memo'],
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
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
              tooltip: '저장',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사진 미리보기
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _imageUrl.isNotEmpty
                    ? Image.network(
                        _imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: 300,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 300,
                            color: Colors.grey[200],
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '이미지를 불러올 수 없습니다',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: 300,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,
                      )
                    : Container(
                        width: double.infinity,
                        height: 300,
                        color: Colors.grey[200],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '이미지를 찾을 수 없습니다',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              // 촬영일시
              Row(
                children: [
                  const Text(
                    '촬영일시:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selectTakenAt,
                      child: Text(
                        _takenAt != null
                            ? DateFormat('yyyy-MM-dd').format(_takenAt!)
                            : '선택',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 위치
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: '위치',
                  hintText: '예: 홍대 포토부스',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 브랜드
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedBrand,
                    decoration: const InputDecoration(
                      labelText: '브랜드',
                      border: OutlineInputBorder(),
                    ),
                    items: _brandOptions
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b,
                            child: Text(b),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedBrand = value;
                        if (value != '직접 입력') {
                          _brandCtrl.text = value;
                        } else {
                          _brandCtrl.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _brandCtrl,
                    enabled: _selectedBrand == '직접 입력',
                    decoration: const InputDecoration(
                      hintText: '직접 입력 (예: 인생네컷)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 태그
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tagCtrl,
                      decoration: const InputDecoration(
                        labelText: '태그',
                        hintText: '태그 입력 후 추가 버튼 클릭',
                        border: OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) => _addTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addTag,
                    tooltip: '태그 추가',
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text('#$tag'),
                          onDeleted: () => _removeTag(tag),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),

              // 친구 선택
              OutlinedButton.icon(
                onPressed: _loadingFriends ? null : _showFriendPicker,
                icon: _loadingFriends
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_outlined),
                label: Text(
                  _selectedFriendIds.isEmpty
                      ? '함께한 친구 선택'
                      : '친구 ${_selectedFriendIds.length}명 선택됨',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              if (_selectedFriendIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _friends
                        .where((f) => _selectedFriendIds.contains(f['userId']))
                        .length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final selected = _friends
                          .where(
                            (f) => _selectedFriendIds.contains(f['userId']),
                          )
                          .toList();
                      final f = selected[i];
                      final avatarUrl =
                          (f['profileImageUrl'] ?? f['avatarUrl']) as String?;
                      final nick =
                          f['nickname'] as String? ?? '친구${f['userId']}';
                      return Column(
                        children: [
                          CircleAvatar(
                            backgroundImage:
                                avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 60,
                            child: Text(
                              nick,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 메모
              TextFormField(
                controller: _memoCtrl,
                decoration: const InputDecoration(
                  labelText: '메모',
                  hintText: '추가 정보를 입력하세요',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 24),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('저장'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
