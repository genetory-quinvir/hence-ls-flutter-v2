import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../common/widgets/common_rounded_button.dart';
import '../../sign/sign_view.dart';

class ProfileNotSignedView extends StatefulWidget {
  const ProfileNotSignedView({super.key});

  @override
  State<ProfileNotSignedView> createState() => _ProfileNotSignedViewState();
}

class _ProfileNotSignedViewState extends State<ProfileNotSignedView> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = List.generate(
      4,
      (index) => 'lib/assets/images/walkthrough/walkthrough_image_$index.webp',
    );
    const titles = [
      '내 주변에서 벌어지는 일들을\n실시간으로 확인하세요',
      '내가 남긴 흔적들을\n아카이빙으로 만나보세요',
      '다양한 스페이스의 이야기들을\n한눈에 살펴보세요',
      '라이브스페이스를 열고,\n지금 이 순간을 함께하세요',
    ];
    const subtitles = [
      '지도에서 다양한 스페이스와\n실시간 상황을 한눈에 확인할 수 있어요.',
      '하루의 활동이 다음 날 아카이빙되어 제공돼요.\n추억을 다시 되짚어볼 수 있어요.',
      '다른 스페이스의 피드를 확인하고,\n관심 있는 스페이스에 참여해보세요.',
      '함께하고 싶은 이순간을 공유하고\n관심사로 연결된 사람들과 소통해보세요.',
    ];

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return SizedBox.expand(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 100, left: 64, right: 64),
                      child: SizedBox(
                        height: 200,
                        child: Image.asset(
                          images[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        titles[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        subtitles[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF8E8E8E),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (index) {
            final isActive = index == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 8 : 6,
              height: isActive ? 8 : 6,
              decoration: BoxDecoration(
                color: isActive ? Colors.black : const Color(0xFFBDBDBD),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
        const SizedBox(height: 80),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CommonRoundedButton(
            title: '회원가입하기',
            onTap: () {
              showCupertinoModalPopup(
                context: context,
                builder: (context) {
                  return SizedBox.expand(
                    child: SignView(),
                  );
                },
              );
            },
            height: 50,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
