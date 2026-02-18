import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hence_ls_flutter_v2/common/widgets/common_inkwell.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../common/auth/auth_store.dart';
import '../common/auth/auth_models.dart';
import '../common/widgets/common_navigation_view.dart';
import '../common/widgets/common_textfield_view.dart';
import '../common/widgets/common_textview_view.dart';
import '../common/widgets/common_title_actionsheet.dart';
import '../common/widgets/common_calendar_view.dart';
import '../common/widgets/common_profile_image_view.dart';
import '../common/permissions/media_permission_service.dart';
import '../common/media/media_picker_service.dart';
import '../common/media/media_conversion_service.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/network/api_client.dart';
import '../common/widgets/common_activity.dart';

class ProfileEditView extends StatefulWidget {
  const ProfileEditView({super.key});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  String _birthText = 'YYYY. MM. DD';
  String _genderText = '성별을 입력하세요';
  bool get _isBirthPlaceholder => _birthText == 'YYYY. MM. DD';
  bool get _isGenderPlaceholder => _genderText == '성별을 입력하세요';
  File? _profileImageFile;
  String? _profileImageUrl;
  TextEditingController? _nicknameController;
  TextEditingController? _introController;
  bool _initialSnapshotSet = false;
  String _initialNickname = '';
  String _initialIntro = '';
  String _initialBirthText = '';
  String _initialGenderText = '';
  String _initialProfileUrl = '';
  bool _isSaving = false;
  bool _didRemoveProfileImage = false;

  bool get _hasProfilePhoto =>
      _profileImageFile != null || (_profileImageUrl?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _ensureControllers();
    _hydrateFromCache();
    _setInitialSnapshotIfNeeded();
  }

  void _ensureControllers() {
    if (_nicknameController == null) {
      _nicknameController = TextEditingController();
      _nicknameController!.addListener(_handleFormChanged);
    }
    if (_introController == null) {
      _introController = TextEditingController();
      _introController!.addListener(_handleFormChanged);
    }
  }

  void _handleFormChanged() {
    if (mounted) setState(() {});
  }

  void _setInitialSnapshotIfNeeded() {
    if (_initialSnapshotSet) return;
    _initialNickname = _nicknameController?.text ?? '';
    _initialIntro = _introController?.text ?? '';
    _initialBirthText = _birthText;
    _initialGenderText = _genderText;
    _initialProfileUrl = _profileImageUrl ?? '';
    _initialSnapshotSet = true;
  }

  bool _isDirty() {
    final currentNickname = _nicknameController?.text ?? '';
    final currentIntro = _introController?.text ?? '';
    final currentBirth = _birthText;
    final currentGender = _genderText;
    final currentProfileUrl = _profileImageUrl ?? '';
    final hasLocalFile = _profileImageFile != null;

    return currentNickname != _initialNickname ||
        currentIntro != _initialIntro ||
        currentBirth != _initialBirthText ||
        currentGender != _initialGenderText ||
        currentProfileUrl != _initialProfileUrl ||
        hasLocalFile;
  }

  String? _mapGenderValue() {
    if (_isGenderPlaceholder) return null;
    switch (_genderText) {
      case '여성':
        return 'FEMALE';
      case '남성':
        return 'MALE';
      case '비밀':
        return 'SECRET';
    }
    return null;
  }

  String _mapGenderLabel(String value) {
    switch (value.toUpperCase()) {
      case 'FEMALE':
        return '여성';
      case 'MALE':
        return '남성';
      case 'SECRET':
        return '비밀';
    }
    return '성별을 입력하세요';
  }

  String _formatDateFromServer(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return _birthText;
    return '${parts[0]}. ${parts[1]}. ${parts[2]}';
  }

  String? _dateOfBirthValue() {
    if (_isBirthPlaceholder) return null;
    final parts = _birthText.split('.').map((e) => e.trim()).toList();
    if (parts.length != 3) return null;
    final y = parts[0].padLeft(4, '0');
    final m = parts[1].padLeft(2, '0');
    final d = parts[2].padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _submitProfile() async {
    if (_isSaving || !_isDirty()) return;
    setState(() => _isSaving = true);
    try {
      final nickname = (_nicknameController?.text ?? '').trim();
      final intro = (_introController?.text ?? '').trim();
      final gender = _mapGenderValue();
      final dateOfBirth = _dateOfBirthValue();

      final updatedUser = await ApiClient.updateProfile(
        nickname: nickname,
        introduction: intro.isEmpty ? null : intro,
        gender: gender,
        dateOfBirth: dateOfBirth,
      );
      await _applyUpdatedUser(
        updatedUser: updatedUser,
        fallbackNickname: nickname,
        fallbackIntro: intro,
        fallbackGender: gender,
        fallbackDateOfBirth: dateOfBirth,
      );

      if (_profileImageFile != null) {
        final uploadFile =
            await MediaConversionService.toWebp(_profileImageFile!);
        final imageUrl = await ApiClient.uploadProfileImage(uploadFile);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _profileImageUrl = imageUrl;
          await _updateCachedProfileImageUrl(imageUrl);
        }
        _profileImageFile = null;
        _didRemoveProfileImage = false;
      } else {
        if (_didRemoveProfileImage) {
          await ApiClient.deleteProfileImage();
          await _updateCachedProfileImageUrl(null);
          _didRemoveProfileImage = false;
        }
      }

      _resetSnapshot();
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      _showPermissionSnack('프로필 편집에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateCachedProfileImageUrl(String? url) async {
    final user = AuthStore.instance.currentUser.value;
    if (user == null) return;
    final updated = AuthUser(
      id: user.id,
      nickname: user.nickname,
      introduction: user.introduction,
      email: user.email,
      provider: user.provider,
      profileImageUrl: url,
      gender: user.gender,
      dateOfBirth: user.dateOfBirth,
    );
    await AuthStore.instance.setUser(updated);
  }

  Future<void> _applyUpdatedUser({
    required AuthUser updatedUser,
    required String fallbackNickname,
    required String fallbackIntro,
    required String? fallbackGender,
    required String? fallbackDateOfBirth,
  }) async {
    final current = AuthStore.instance.currentUser.value;
    if (current == null) return;

    final merged = _mergeUser(
      current: current,
      incoming: updatedUser,
      fallbackNickname: fallbackNickname,
      fallbackIntro: fallbackIntro,
      fallbackGender: fallbackGender,
      fallbackDateOfBirth: fallbackDateOfBirth,
    );
    await AuthStore.instance.setUser(merged);
    _profileImageUrl = merged.profileImageUrl ?? _profileImageUrl;
  }

  AuthUser _mergeUser({
    required AuthUser current,
    required AuthUser incoming,
    required String fallbackNickname,
    required String fallbackIntro,
    required String? fallbackGender,
    required String? fallbackDateOfBirth,
  }) {
    String pickString(String? a, String? b, String fallback) {
      if (a != null && a.trim().isNotEmpty) return a;
      if (b != null && b.trim().isNotEmpty) return b;
      return fallback;
    }

    return AuthUser(
      id: current.id,
      nickname: pickString(incoming.nickname, current.nickname, fallbackNickname),
      introduction: pickString(incoming.introduction, current.introduction, fallbackIntro),
      email: incoming.email ?? current.email,
      provider: incoming.provider ?? current.provider,
      profileImageUrl: (incoming.profileImageUrl != null &&
              incoming.profileImageUrl!.trim().isNotEmpty)
          ? incoming.profileImageUrl
          : current.profileImageUrl,
      gender: incoming.gender ?? fallbackGender ?? current.gender,
      dateOfBirth: incoming.dateOfBirth ?? fallbackDateOfBirth ?? current.dateOfBirth,
    );
  }

  void _resetSnapshot() {
    _initialNickname = _nicknameController?.text ?? '';
    _initialIntro = _introController?.text ?? '';
    _initialBirthText = _birthText;
    _initialGenderText = _genderText;
    _initialProfileUrl = _profileImageUrl ?? '';
    _initialSnapshotSet = true;
  }

  void _hydrateFromCache() {
    final user = AuthStore.instance.currentUser.value;
    if (user == null) return;
    if (user.nickname.isNotEmpty) {
      _nicknameController?.text = user.nickname;
    }
    if (user.introduction != null && user.introduction!.trim().isNotEmpty) {
      _introController?.text = user.introduction!;
    }
    if (user.gender != null && user.gender!.isNotEmpty) {
      _genderText = _mapGenderLabel(user.gender!);
    }
    if (user.dateOfBirth != null && user.dateOfBirth!.isNotEmpty) {
      _birthText = _formatDateFromServer(user.dateOfBirth!);
    }
    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      _profileImageUrl = user.profileImageUrl;
    }
  }

  @override
  void dispose() {
    _nicknameController?.removeListener(_handleFormChanged);
    _introController?.removeListener(_handleFormChanged);
    _nicknameController?.dispose();
    _introController?.dispose();
    super.dispose();
  }

  Future<void> _showPhotoActionSheet() async {
    final items = <CommonTitleActionSheetItem>[
      const CommonTitleActionSheetItem(label: '앨범에서 가져오기', value: 'album'),
      const CommonTitleActionSheetItem(label: '카메라로 촬영하기', value: 'camera'),
      if (_hasProfilePhoto)
        const CommonTitleActionSheetItem(
          label: '프로필 사진 삭제하기',
          isDestructive: true,
          value: 'delete',
        ),
    ];

    await CommonTitleActionSheet.show(
      context,
      title: '프로필 사진',
      items: items,
      onSelected: (item) async {
        switch (item.value) {
          case 'album':
            if (!await MediaPermissionService.ensurePhotoLibrary()) {
              _showPermissionSnack('사진 접근 권한이 필요합니다.');
              return;
            }
            final picked = await MediaPickerService.pickFromGallery();
            if (picked == null) return;
            setState(() {
              _profileImageFile = File(picked.path);
              _profileImageUrl = null;
            });
            break;
          case 'camera':
            if (!await MediaPermissionService.ensureCamera()) {
              _showPermissionSnack('카메라 권한이 필요합니다.');
              return;
            }
            final picked = await MediaPickerService.pickFromCamera();
            if (picked == null) return;
            setState(() {
              _profileImageFile = File(picked.path);
              _profileImageUrl = null;
            });
            break;
          case 'delete':
            setState(() {
              _profileImageFile = null;
              _profileImageUrl = null;
              _didRemoveProfileImage = true;
            });
            break;
        }
      },
    );
  }

  void _showPermissionSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureControllers();
    _setInitialSnapshotIfNeeded();
    final canSubmit = _isDirty() && !_isSaving;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: CommonNavigationView(
                  left: const Icon(
                    PhosphorIconsRegular.caretLeft,
                    size: 24,
                    color: Colors.black,
                  ),
                  onLeftTap: () => Navigator.of(context).maybePop(),
                  title: '프로필 편집',
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _ProfilePhotoSection(
                      onCameraTap: _showPhotoActionSheet,
                      imageFile: _profileImageFile,
                      imageUrl: _profileImageUrl,
                    ),
                    const SizedBox(height: 20),
                    _InputField(
                      label: '닉네임',
                      hintText: '닉네임을 입력하세요',
                      maxLength: 10,
                      controller: _nicknameController,
                    ),
                    const SizedBox(height: 16),
                    _InputField(
                      label: '자기소개',
                      hintText: '자기소개를 입력하세요',
                      maxLines: 4,
                      maxLength: 80,
                      useTextView: true,
                      controller: _introController,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '추가정보',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      label: '생년월일',
                      hintText: _birthText,
                      showCounter: false,
                      useInkWell: true,
                      isPlaceholder: _isBirthPlaceholder,
                      onTap: () async {
                        final picked = await CommonCalendarView.show(context);
                        if (picked == null) return;
                        setState(() => _birthText = _formatDate(picked));
                      },
                    ),
                    const SizedBox(height: 16),
                    _InputField(
                      label: '성별',
                      hintText: _genderText,
                      showCounter: false,
                      useInkWell: true,
                      isPlaceholder: _isGenderPlaceholder,
                      onTap: () {
                        CommonTitleActionSheet.show(
                          context,
                          title: '성별',
                          items: const [
                            CommonTitleActionSheetItem(label: '여성'),
                            CommonTitleActionSheetItem(label: '남성'),
                            CommonTitleActionSheetItem(label: '비밀'),
                          ],
                          onSelected: (value) {
                            setState(() => _genderText = value.label);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: CommonRoundedButton(
                    title: '프로필 편집하기',
                    onTap: canSubmit ? _submitProfile : null,
                    backgroundColor:
                        canSubmit ? Colors.black : const Color(0xFFE0E0E0),
                    textColor:
                        canSubmit ? Colors.white : const Color(0xFF9E9E9E),
                  ),
                ),
              ),
            ],
          ),
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: CommonActivityIndicator(
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y. $m. $d';
}

class _ProfilePhotoSection extends StatelessWidget {
  const _ProfilePhotoSection({
    this.onCameraTap,
    this.imageFile,
    this.imageUrl,
  });

  final VoidCallback? onCameraTap;
  final File? imageFile;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CommonProfileImageView(
            size: 120,
            imageFile: imageFile,
            imageUrl: imageUrl,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
              ),
              child: CommonInkWell(
                  onTap: onCameraTap,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      PhosphorIconsRegular.camera,
                      size: 18,
                      color: Colors.white,
                    ),
                ),
              ),
            )
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.hintText,
    this.maxLines = 1,
    this.maxLength,
    this.useTextView = false,
    this.useInkWell = false,
    this.showCounter = true,
    this.onTap,
    this.isPlaceholder = true,
    this.controller,
  });

  final String label;
  final String hintText;
  final int maxLines;
  final int? maxLength;
  final bool useTextView;
  final bool useInkWell;
  final bool showCounter;
  final VoidCallback? onTap;
  final bool isPlaceholder;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    if (useInkWell) {
      return _SelectionField(
        title: label,
        hintText: hintText,
        onTap: onTap,
        isPlaceholder: isPlaceholder,
      );
    }
    if (useTextView) {
      return CommonTextViewView(
        title: label,
        hintText: hintText,
        maxLines: maxLines,
        maxLength: maxLength,
        controller: controller,
      );
    }
    return CommonTextFieldView(
      title: label,
      hintText: hintText,
      maxLines: maxLines,
      maxLength: showCounter ? maxLength : null,
      controller: controller,
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.title,
    required this.hintText,
    this.onTap,
    this.isPlaceholder = true,
  });

  final String title;
  final String hintText;
  final VoidCallback? onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return CommonInkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 20,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF757575),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hintText,
                style: TextStyle(
                  fontSize: 16,
                  color: isPlaceholder
                      ? Colors.black.withOpacity(0.35)
                      : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
