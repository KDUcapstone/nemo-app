import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/services/album_api.dart';
import 'package:provider/provider.dart';
import 'package:frontend/presentation/screens/album/select_album_photos_screen.dart';
import 'package:frontend/providers/photo_provider.dart';
import 'package:image_picker/image_picker.dart';

class CreateAlbumScreen extends StatefulWidget {
  final List<int>? initialSelectedPhotoIds;
  const CreateAlbumScreen({super.key, this.initialSelectedPhotoIds});

  @override
  State<CreateAlbumScreen> createState() => _CreateAlbumScreenState();
}

class _CreateAlbumScreenState extends State<CreateAlbumScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _submitting = false;
  int? _coverPhotoId;
  final Set<int> _selectedPhotoIds = {};
  bool _isScrolling = false; // 스크롤 중인지 추적
  File? _coverFile; // 대표사진 파일 업로드용
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelectedPhotoIds;
    if (initial != null && initial.isNotEmpty) {
      _selectedPhotoIds
        ..clear()
        ..addAll(initial);
      _coverPhotoId ??= _selectedPhotoIds.first;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final created = await AlbumApi.createAlbum(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        coverPhotoId: _coverPhotoId,
        photoIdList: _selectedPhotoIds.isEmpty
            ? null
            : _selectedPhotoIds.toList(),
      );
      if (!mounted) return;

      // 대표사진 파일이 있으면 썸네일 업로드 API 호출
      if (_coverFile != null) {
        try {
          final albumId = (created['albumId'] as num).toInt();
          final thumbnailRes = await AlbumApi.uploadThumbnailFile(
            albumId: albumId,
            file: _coverFile!,
          );
          // 썸네일 URL은 이전 화면에서 Provider로 반영
          created['coverPhotoUrl'] =
              thumbnailRes['thumbnailUrl'] as String? ??
              created['coverPhotoUrl'];
        } catch (e) {
          // 썸네일 업로드 실패는 치명적이지 않으므로 로그만 출력
          debugPrint('⚠️ 앨범 썸네일 파일 업로드 실패: $e');
        }
      }

      final title = created['title'] as String? ?? '앨범';

      // SnackBar 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('앨범 생성 완료: $title')));

      // Navigator.pop을 먼저 호출하고, 결과를 반환
      // Provider 업데이트는 이전 화면에서 처리하도록 함
      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('앨범 생성 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateTitle(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return '앨범명을 입력하세요';
    if (value.length > 50) return '앨범명은 50자 이내로 입력하세요';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 키보드 inset을 직접 사용하되, AnimatedPadding으로 부드럽게 처리
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      // 키보드가 올라올 때 레이아웃이 변경되지 않도록 설정
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('새 앨범 만들기')),
      body: SafeArea(
        bottom: true,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // 스크롤 시작 시 키보드 닫기 (스와이프로 키보드 닫기)
            if (notification is ScrollStartNotification) {
              setState(() {
                _isScrolling = true;
              });
              FocusScope.of(context).unfocus();
            } else if (notification is ScrollEndNotification) {
              // 스크롤 종료 후 약간의 지연으로 상태 리셋
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() {
                    _isScrolling = false;
                  });
                }
              });
            }
            return false;
          },
          child: SingleChildScrollView(
            // 스크롤 중일 때는 viewInsets 변경을 무시하여 충돌 방지
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + (_isScrolling ? 0 : bottomInset),
            ),
            // manual로 설정하고 NotificationListener로 처리
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            // 오버스크롤 인디케이터 비활성화하여 키보드 닫힐 때 충돌 방지
            physics: const ClampingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '앨범명',
                      hintText: '예: 제주도 여행',
                    ),
                    validator: _validateTitle,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: '설명 (선택)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final selected = await Navigator.push<List<int>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SelectAlbumPhotosScreen(),
                              ),
                            );
                            if (selected != null && mounted) {
                              setState(() {
                                _selectedPhotoIds
                                  ..clear()
                                  ..addAll(selected);
                                if (_selectedPhotoIds.isNotEmpty) {
                                  _coverPhotoId = _selectedPhotoIds.first;
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _selectedPhotoIds.isEmpty
                                ? '사진 선택'
                                : '사진 ${_selectedPhotoIds.length}장 선택됨',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // 선택지: 이미 선택한 사진 중에서 고르기 / 파일 업로드
                            final choice = await showModalBottomSheet<String>(
                              context: context,
                              builder: (_) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('선택한 사진 중에서 고르기'),
                                      onTap: () =>
                                          Navigator.pop(context, 'selected'),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.upload_file),
                                      title: const Text('파일 업로드'),
                                      onTap: () =>
                                          Navigator.pop(context, 'upload'),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.cancel),
                                      title: const Text('취소'),
                                      onTap: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            if (choice == 'selected') {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) {
                                  final items = context
                                      .read<PhotoProvider>()
                                      .items;
                                  final selectedList = _selectedPhotoIds
                                      .toList();
                                  return SafeArea(
                                    child: SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.6,
                                      child: GridView.builder(
                                        padding: const EdgeInsets.all(12),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              mainAxisSpacing: 8,
                                              crossAxisSpacing: 8,
                                            ),
                                        itemCount: selectedList.length,
                                        itemBuilder: (_, i) {
                                          final pid = selectedList[i];
                                          final idx = items.indexWhere(
                                            (e) => e.photoId == pid,
                                          );
                                          final url = idx != -1
                                              ? items[idx].imageUrl
                                              : '';
                                          final isFile =
                                              url.isNotEmpty &&
                                              !url.startsWith('http');
                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _coverPhotoId = pid;
                                                _coverFile = null;
                                              });
                                              Navigator.pop(context);
                                            },
                                            child: url.isNotEmpty
                                                ? (isFile
                                                      ? Image.file(
                                                          File(url),
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => const ColoredBox(
                                                                color: Color(
                                                                  0xFFE0E0E0,
                                                                ),
                                                              ),
                                                        )
                                                      : Image.network(
                                                          url,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => const ColoredBox(
                                                                color: Color(
                                                                  0xFFE0E0E0,
                                                                ),
                                                              ),
                                                        ))
                                                : const ColoredBox(
                                                    color: Color(0xFFE0E0E0),
                                                  ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            } else if (choice == 'upload') {
                              final XFile? image = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (image != null && mounted) {
                                setState(() {
                                  _coverFile = File(image.path);
                                  _coverPhotoId = null;
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('대표사진 수정'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final items = context.watch<PhotoProvider>().items;
                      String url = '';
                      if (_coverPhotoId != null) {
                        final idx = items.indexWhere(
                          (e) => e.photoId == _coverPhotoId,
                        );
                        url = idx != -1 ? items[idx].imageUrl : '';
                      }

                      final hasFile = _coverFile != null;
                      final hasUrl = url.isNotEmpty;

                      if (!hasFile && !hasUrl) {
                        return const SizedBox.shrink();
                      }

                      // 모킹 모드에서 로컬 파일 경로인 경우 처리
                      final isFileFromUrl =
                          url.isNotEmpty && !url.startsWith('http');

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: hasFile
                              ? Image.file(
                                  _coverFile!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                        color: Color(0xFFE0E0E0),
                                      ),
                                )
                              : hasUrl
                              ? (isFileFromUrl
                                    ? Image.file(
                                        File(url),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const ColoredBox(
                                              color: Color(0xFFE0E0E0),
                                            ),
                                      )
                                    : Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const ColoredBox(
                                              color: Color(0xFFE0E0E0),
                                            ),
                                      ))
                              : const ColoredBox(color: Color(0xFFE0E0E0)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.check),
                      label: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('생성'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 초기 선택 사진을 인자로 받아 바로 제목/설명만 입력하도록 보여주는 진입용 위젯
class CreateAlbumScreenInitial extends StatelessWidget {
  final List<int> selectedPhotoIds;
  const CreateAlbumScreenInitial({super.key, required this.selectedPhotoIds});

  @override
  Widget build(BuildContext context) {
    return CreateAlbumScreenWithInitial(selectedPhotoIds: selectedPhotoIds);
  }
}

class CreateAlbumScreenWithInitial extends StatefulWidget {
  final List<int> selectedPhotoIds;
  const CreateAlbumScreenWithInitial({
    super.key,
    required this.selectedPhotoIds,
  });

  @override
  State<CreateAlbumScreenWithInitial> createState() =>
      _CreateAlbumScreenWithInitialState();
}

class _CreateAlbumScreenWithInitialState
    extends State<CreateAlbumScreenWithInitial> {
  @override
  Widget build(BuildContext context) {
    return CreateAlbumScreen(initialSelectedPhotoIds: widget.selectedPhotoIds);
  }
}
