import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common/auth/auth_store.dart';
import '../../common/widgets/common_profile_view.dart';
import '../../common/widgets/common_rounded_button.dart';
import '../../profile_edit/profile_edit_view.dart';

class ProfileSignedView extends StatelessWidget {
  const ProfileSignedView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      children: const [
        _ProfileUserSection(),
      ],
    );
  }
}

class _ProfileUserSection extends StatelessWidget {
  const _ProfileUserSection();

  String? _providerIconAsset(String? provider) {
    switch (provider?.toLowerCase()) {
      case 'naver':
        return 'lib/assets/images/icon_naver.svg';
      case 'kakao':
        return 'lib/assets/images/icon_kakao.svg';
      case 'google':
        return 'lib/assets/images/icon_google.svg';
      case 'apple':
        return 'lib/assets/images/icon_apple.svg';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AuthStore.instance.currentUser,
      builder: (context, user, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: AuthStore.instance.lastProvider,
          builder: (context, provider, _) {
            final nickname = (user?.nickname.trim().isNotEmpty ?? false) ? user!.nickname : '사용자';
            final email = (user?.email?.trim().isNotEmpty ?? false) ? user!.email! : '';
            final effectiveProvider =
                (user?.provider?.trim().isNotEmpty ?? false) ? user!.provider : provider;
            final providerIcon = _providerIconAsset(effectiveProvider);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CommonProfileView(networkUrl: user?.profileImageUrl, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          children: [
                            // if (providerIcon != null) ...[
                            //   SvgPicture.asset(
                            //     providerIcon,
                            //     width: 16,
                            //     height: 16,
                            //   ),
                            //   const SizedBox(width: 4),
                            // ],
                            Expanded(
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF8E8E8E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 50,
                    child: CommonRoundedButton(
                      title: '편집',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileEditView()),
                        );
                      },
                      height: 32,
                      radius: 8,
                      backgroundColor: const Color(0xFFF5F5F5),
                      textColor: Colors.black,
                      textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
