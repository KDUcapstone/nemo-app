// 📁 lib/presentation/screens/user/mypage_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/theme/app_colors.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../login/login_screen.dart';

// 위젯 imports
import 'widgets/glass_card.dart';
// removed unused: icon_input_field, primary/secondary button (moved into widgets)
import 'widgets/info_row.dart';
// removed unused: menu_button
import 'widgets/profile_card.dart';
import 'widgets/account_actions_card.dart';
import 'widgets/profile_image_picker_sheet.dart';
import 'widgets/sky_background.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:frontend/services/photo_upload_api.dart';
import 'change_password_screen.dart';
import 'package:frontend/services/friend_api.dart';
import 'friends_list_screen.dart';
import 'widgets/storage_quota_card.dart';
import 'package:frontend/services/storage_api.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late Future<StorageQuota> _quotaFuture;

  // 임시 사용자 데이터 (실제로는 API에서 가져옴)
  Map<String, dynamic> _userInfo = {
    'id': 1,
    'email': 'user@example.com',
    'nickname': '사용자',
    'profileImageUrl': null,
    'createdAt': '2024-01-01',
  };

  File? _selectedImage;
  bool _isLoading = false;
  bool _isEditing = false;

  DateTime? _parseCreatedAt(dynamic value) {
    try {
      if (value == null) return null;
      if (value is DateTime) return value.toLocal();
      if (value is int) {
        // epoch seconds or milliseconds
        final isMillis = value > 100000000000; // ~2001-09-09 in ms
        final dt = isMillis
            ? DateTime.fromMillisecondsSinceEpoch(value)
            : DateTime.fromMillisecondsSinceEpoch(value * 1000);
        return dt.toLocal();
      }
      if (value is String) {
        // ISO or yyyy-MM-dd
        final dt = DateTime.parse(value);
        return dt.toLocal();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _formatJoinedAt(dynamic value) {
    final dt = _parseCreatedAt(value);
    if (dt == null) return '-';
    return DateFormat('yyyy.MM.dd').format(dt);
  }

  @override
  void initState() {
    super.initState();
    _nicknameController.text = _userInfo['nickname'];
    _loadUserInfo();
    _quotaFuture = StorageApi.fetchQuota();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final response = await authService.getUserInfo();

      setState(() {
        _userInfo = response;
        _nicknameController.text = response['nickname'] as String;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사용자 정보를 불러오는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다')));
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진 촬영 중 오류가 발생했습니다')));
      }
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ProfileImagePickerSheet(
          onTakePhoto: _takePhoto,
          onPickGallery: _pickImage,
        );
      },
    );
  }

  // QR 스캔 진입은 하단 탭에서 제공되며, 마이페이지에서는 제거되었습니다.

  // QR 가져오기는 현재 마이페이지에서 직접 호출하지 않습니다. (탭 구조 적용)
  // ignore: unused_element
  Future<void> _importFromQr(String payload) async {
    final match = RegExp(r'https?://[^\s]+').firstMatch(payload);
    if (match == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지원되지 않는 QR 형식입니다.')));
      return;
    }
    final url = match.group(0)!;

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final Uint8List bytes = resp.bodyBytes;
        if (!mounted) return;
        final tempDir = Directory.systemTemp;
        final fileName =
            'qr_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = p.join(tempDir.path, fileName);
        final file = await File(filePath).writeAsBytes(bytes);

        final nowIso = DateFormat("yyyy-MM-ddTHH:mm:ss").format(DateTime.now());
        final api = PhotoUploadApi();
        final result = await api.uploadPhotoViaQr(
          qrCode: payload,
          imageFile: file,
          takenAtIso: nowIso,
          location: '포토부스(추정)',
          brand: '인생네컷',
          tagList: const ['QR업로드'],
          friendIdList: const [],
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 완료 (ID: ${result['photoId']})')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 불러오지 못했습니다 (${resp.statusCode})')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('가져오기 실패: $e')));
    }
  }

  // 닉네임 검증은 ProfileCard 내부에서 처리하므로 이 화면에서는 미사용 상태입니다.

  Future<void> _updateUserInfo() async {
    final formState = _formKey.currentState;
    if (formState != null) {
      if (!formState.validate()) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();

      // 프로필 이미지가 선택된 경우, 먼저 업로드해야 함
      // TODO: 프로필 이미지 업로드 API가 별도로 있다면 여기서 호출
      // 현재는 닉네임만 업데이트

      // PATCH /api/users/me
      final response = await authService.updateUserInfo(
        nickname: _nicknameController.text,
        profileImageUrl: _userInfo['profileImageUrl'] as String?, // 기존 URL 유지
      );

      // 업데이트된 정보로 상태 갱신
      setState(() {
        _userInfo['nickname'] = response['nickname'] as String;
        _userInfo['profileImageUrl'] = response['profileImageUrl'] as String?;
        _selectedImage = null; // 선택된 이미지 초기화
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정보가 성공적으로 수정되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('정보 수정 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                if (mounted) {
                  Navigator.of(context).pop(false);
                }
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      await authService.logout();

      // UserProvider에서도 로그아웃 처리
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.logout();
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그아웃되었습니다')));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그아웃 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    // 1단계: 상세한 경고 메시지
    final showWarning = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: GoogleFonts.notoSansTextTheme(
              Theme.of(context).textTheme,
            ),
            // Use default dialogTheme; apply font via textTheme above
          ),
          child: AlertDialog(
            title: const Text(
              '회원탈퇴 안내',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '회원탈퇴 시 다음 데이터가 영구적으로 삭제됩니다:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildWarningItem('• 개인 정보 (이메일, 닉네임, 프로필 이미지)'),
                  _buildWarningItem('• 모든 리캡 카드와 앨범'),
                  _buildWarningItem('• 업로드된 사진들'),
                  _buildWarningItem('• 친구 목록 및 관계'),
                  _buildWarningItem('• 앱 사용 기록'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '탈퇴 후에는 복구가 불가능합니다!',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '중요한 사진이나 앨범이 있다면 먼저 백업하시기를 권장합니다.',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 153, 0),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.of(context).pop(false);
                  }
                },
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('탈퇴 진행'),
              ),
            ],
          ),
        );
      },
    );

    if (showWarning != true) return;

    // 2단계: 비밀번호 확인
    final passwordController = TextEditingController();
    final passwordConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: GoogleFonts.notoSansTextTheme(
              Theme.of(context).textTheme,
            ),
            // Use default dialogTheme
          ),
          child: AlertDialog(
            title: const Text(
              '비밀번호 확인',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '회원탈퇴를 위해\n현재 비밀번호를 입력해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    return null;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                },
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  if (passwordController.text.isNotEmpty && mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('탈퇴 확인'),
              ),
            ],
          ),
        );
      },
    );

    if (passwordConfirmed != true) return;

    // 3단계: 최종 확인
    final finalConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: GoogleFonts.notoSansTextTheme(
              Theme.of(context).textTheme,
            ),
            // Use default dialogTheme
          ),
          child: AlertDialog(
            title: const Text(
              '최종 확인',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  '정말로 회원탈퇴를 진행하시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '이 작업은 되돌릴 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                },
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('탈퇴 완료'),
              ),
            ],
          ),
        );
      },
    );

    if (finalConfirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      await authService.deleteAccount(passwordController.text);

      if (mounted) {
        // UserProvider에서도 로그아웃 처리
        if (mounted) {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          userProvider.logout();
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원탈퇴가 완료되었습니다. 그동안 이용해주셔서 감사했습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원탈퇴 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallHeight = size.height < 720;
    final double outerVertical = isSmallHeight ? 16 : 32;
    final double gap = isSmallHeight ? 12 : 20;
    final double innerGap = isSmallHeight ? 8 : 12;
    return Scaffold(
      body: Stack(
        children: [
          const SkyBackground(),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      outerVertical,
                      24,
                      outerVertical + 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 헤더
                        Center(
                          child: Text(
                            '마이페이지',
                            style: GoogleFonts.jua(
                              fontSize: 24,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(height: gap),

                        // 프로필 섹션 (분리 위젯 사용)
                        ProfileCard(
                          isEditing: _isEditing,
                          nicknameController: _nicknameController,
                          email: _userInfo['email'],
                          nickname: _userInfo['nickname'],
                          profileImageUrl: _userInfo['profileImageUrl'],
                          selectedImage: _selectedImage,
                          onEdit: () => setState(() => _isEditing = true),
                          onCancel: () => setState(() {
                            _isEditing = false;
                            _nicknameController.text = _userInfo['nickname'];
                            _selectedImage = null;
                          }),
                          onSave: _updateUserInfo,
                          onOpenImagePicker: _showImagePickerDialog,
                        ),
                        SizedBox(height: gap),

                        // 저장 한도/사용량 (프로필과 계정 정보 사이)
                        FutureBuilder<StorageQuota>(
                          future: _quotaFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Card(
                                elevation: 0,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: LinearProgressIndicator(),
                                ),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              return Card(
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          '저장 한도 정보를 불러오지 못했습니다.',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _quotaFuture =
                                                StorageApi.fetchQuota();
                                          });
                                        },
                                        child: const Text('다시 시도'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            final quota = snapshot.data!;
                            return StorageQuotaCard(
                              quota: quota,
                              onUpgrade: () {
                                // 업그레이드 플로우 진입 (추후 결제/구독 화면 연결)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('업그레이드 준비 중입니다.'),
                                  ),
                                );
                              },
                              capFreeAtTwenty: true,
                            );
                          },
                        ),
                        SizedBox(height: gap),

                        // 계정 정보
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '계정 정보',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: isSmallHeight ? 10 : 16),
                              InfoRow(
                                label: '가입일',
                                value: _formatJoinedAt(_userInfo['createdAt']),
                                icon: Icons.calendar_today,
                              ),
                              SizedBox(height: innerGap),
                              InfoRow(
                                label: '이메일',
                                value: _userInfo['email'],
                                icon: Icons.email,
                              ),
                              SizedBox(height: innerGap),
                              _FriendsEntryRow(),
                            ],
                          ),
                        ),
                        SizedBox(height: gap),

                        // 계정 관리
                        AccountActionsCard(
                          onLogout: _logout,
                          onDelete: _deleteAccount,
                          onResetPassword: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: gap),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FriendsEntryRow extends StatefulWidget {
  @override
  State<_FriendsEntryRow> createState() => _FriendsEntryRowState();
}

class _FriendsEntryRowState extends State<_FriendsEntryRow> {
  int? _friendCount;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchCount();
  }

  Future<void> _fetchCount() async {
    setState(() => _loading = true);
    try {
      final list = await FriendApi.getFriends();
      if (!mounted) return;
      setState(() {
        _friendCount = list.length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final countText = _loading
        ? '불러오는 중...'
        : _friendCount == null
        ? '친구'
        : '친구 ${_friendCount}명';

    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FriendsListScreen()));
      },
      child: Row(
        children: [
          const Icon(
            Icons.group_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '친구',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  countText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
