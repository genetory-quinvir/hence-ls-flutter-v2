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
      (index) => 'assets/images/walkthrough/walkthrough_image_$index.webp',
    );
    const titles = [
      '사람들만 아는 장소를\n담아두는 지도',
      '좋았던 순간의 장소를\n잊지 않게',
      '상황에 맞는 장소를\n한눈에',
      '모을수록 더 선명해지는\n나만의 HENCE',
    ];
    const subtitles = [
      '검색으로는 찾기 어려운\n일상 속 진짜 스팟을 기록해보세요.',
      '혼자 쉬던 곳, 다시 가고 싶은 곳,\n기억해두고 싶은 자리를 저장할 수 있어요.',
      '쉬기, 산책, 분위기, 무료 편의처럼\n필요한 순간에 맞게 찾아볼 수 있어요.',
      '장소 하나하나가 쌓여\n당신만의 생활 지도가 완성됩니다.',
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
