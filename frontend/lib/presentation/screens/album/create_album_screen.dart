import 'package:flutter/material.dart';
import 'package:frontend/services/album_api.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/album_provider.dart';
import 'package:frontend/presentation/screens/album/select_album_photos_screen.dart';
import 'package:frontend/providers/photo_provider.dart';

class CreateAlbumScreen extends StatefulWidget {
  const CreateAlbumScreen({super.key});

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
      context.read<AlbumProvider>().addFromResponse(created);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('앨범 생성 완료: ${created['title']}')));
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
    return Scaffold(
      appBar: AppBar(title: const Text('새 앨범 만들기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
                            // 자동으로 대표사진을 첫 번째 선택으로 지정
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
                      onPressed: _selectedPhotoIds.isEmpty
                          ? null
                          : () async {
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
                                          return GestureDetector(
                                            onTap: () {
                                              setState(
                                                () => _coverPhotoId = pid,
                                              );
                                              Navigator.pop(context);
                                            },
                                            child: url.isNotEmpty
                                                ? Image.network(
                                                    url,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            const ColoredBox(
                                                              color: Color(
                                                                0xFFE0E0E0,
                                                              ),
                                                            ),
                                                  )
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
                  if (_coverPhotoId == null) return const SizedBox.shrink();
                  final items = context.watch<PhotoProvider>().items;
                  final idx = items.indexWhere(
                    (e) => e.photoId == _coverPhotoId,
                  );
                  final url = idx != -1 ? items[idx].imageUrl : '';
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: url.isNotEmpty
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Color(0xFFE0E0E0)),
                            )
                          : const ColoredBox(color: Color(0xFFE0E0E0)),
                    ),
                  );
                },
              ),
              const Spacer(),
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
    return CreateAlbumScreenWrapper(initialSelected: widget.selectedPhotoIds);
  }
}

class CreateAlbumScreenWrapper extends StatefulWidget {
  final List<int> initialSelected;
  const CreateAlbumScreenWrapper({super.key, required this.initialSelected});

  @override
  State<CreateAlbumScreenWrapper> createState() =>
      _CreateAlbumScreenWrapperState();
}

class _CreateAlbumScreenWrapperState extends State<CreateAlbumScreenWrapper> {
  @override
  Widget build(BuildContext context) {
    return CreateAlbumScreenInternal(initialSelected: widget.initialSelected);
  }
}

class CreateAlbumScreenInternal extends StatefulWidget {
  final List<int> initialSelected;
  const CreateAlbumScreenInternal({super.key, required this.initialSelected});

  @override
  State<CreateAlbumScreenInternal> createState() =>
      _CreateAlbumScreenInternalState();
}

class _CreateAlbumScreenInternalState extends State<CreateAlbumScreenInternal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.findAncestorStateOfType<_CreateAlbumScreenState>();
      if (state != null) {
        state.setState(() {
          state._selectedPhotoIds
            ..clear()
            ..addAll(widget.initialSelected);
          if (state._selectedPhotoIds.isNotEmpty) {
            state._coverPhotoId ??= state._selectedPhotoIds.first;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const CreateAlbumScreen();
  }
}
