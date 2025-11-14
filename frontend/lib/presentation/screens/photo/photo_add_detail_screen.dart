import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/photo_upload_api.dart';
import 'package:frontend/services/friend_api.dart';
import 'package:frontend/providers/photo_provider.dart';

class PhotoAddDetailScreen extends StatefulWidget {
  final File imageFile;
  final String? qrCode; // QR 스캔인 경우 QR 코드 값
  final DateTime? defaultTakenAt; // 기본 촬영일시

  const PhotoAddDetailScreen({
    super.key,
    required this.imageFile,
    this.qrCode,
    this.defaultTakenAt,
  });

  @override
  State<PhotoAddDetailScreen> createState() => _PhotoAddDetailScreenState();
}

class _PhotoAddDetailScreenState extends State<PhotoAddDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  DateTime? _takenAt;
  List<String> _tags = [];
  Set<int> _selectedFriendIds = {};
  bool _loading = false;
  bool _loadingFriends = false;
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    _takenAt = widget.defaultTakenAt ?? DateTime.now();
    // QR에서 추정 가능한 정보 기본값 설정
    if (widget.qrCode != null) {
      _locationCtrl.text = '포토부스(추정)';
      _brandCtrl.text = '인생네컷';
      _tags = ['QR업로드'];
    }
    _loadFriends();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _brandCtrl.dispose();
    _memoCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
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

  Future<void> _uploadPhoto() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_takenAt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('촬영일시를 선택해주세요.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final takenAtIso = DateFormat("yyyy-MM-ddTHH:mm:ss").format(_takenAt!);
      final api = PhotoUploadApi();

      final result = await api.uploadPhotoViaQr(
        qrCode: widget.qrCode ?? '',
        imageFile: widget.imageFile,
        takenAtIso: takenAtIso,
        location: _locationCtrl.text.trim().isEmpty
            ? '미지정'
            : _locationCtrl.text.trim(),
        brand: _brandCtrl.text.trim().isEmpty ? '미지정' : _brandCtrl.text.trim(),
        tagList: _tags.isEmpty ? null : _tags,
        friendIdList: _selectedFriendIds.isEmpty
            ? null
            : _selectedFriendIds.toList(),
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      );

      if (!context.mounted) return;

      // 상태 반영
      context.read<PhotoProvider>().addFromResponse(result);

      // 성공 알림 후 뒤로가기
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진이 추가되었습니다.')));
      Navigator.pop(context, true); // true를 반환하여 성공 표시
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 정보 입력'),
        actions: [
          if (_loading)
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
              onPressed: _uploadPhoto,
              tooltip: '사진 추가',
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
                child: widget.imageFile.existsSync()
                    ? Image.file(
                        widget.imageFile,
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
                              '파일을 찾을 수 없습니다',
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
              TextFormField(
                controller: _brandCtrl,
                decoration: const InputDecoration(
                  labelText: '브랜드',
                  hintText: '예: 인생네컷',
                  border: OutlineInputBorder(),
                ),
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

              // 업로드 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _uploadPhoto,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: const Text('사진 추가'),
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
