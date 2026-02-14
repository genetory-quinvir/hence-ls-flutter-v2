import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common/widgets/common_inkwell.dart';

class ProfileActivityInfoView extends StatelessWidget {
  const ProfileActivityInfoView({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return const SafeArea(
          top: false,
          child: ProfileActivityInfoView(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '활동 지수 안내',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              CommonInkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    PhosphorIconsRegular.x,
                    size: 20,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '최근 2주간의 활동을 바탕으로\n참여도 점수를 계산해 보여줘요.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _LevelRow(levels: const [0, 1, 2, 3, 4, 5]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(
                PhosphorIconsRegular.info,
                size: 20,
                color: Color(0xFF616161),
              ),
              SizedBox(width: 4),
              Text(
                '어떻게 계산되나요?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF616161),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DotRow(
            text:
                '라이브스페이스 만들기, 피드 작성, 체크인 등 다양한 활동을 점수로 계산해요.',
          ),
          const SizedBox(height: 8),
          _DotRow(
            text:
                '단, 도배나 반복 체크인 등 부적절한 활동으로 발생한 점수는 회수될 수 있어요.',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DotRow extends StatelessWidget {
  const _DotRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF616161),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF616161),
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelItem extends StatelessWidget {
  const _LevelItem({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/images/levels/icon_level_$level.svg',
          width: 28,
          height: 28,
        ),
        const SizedBox(height: 4),
        Text(
          'LV. $level',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF616161),
          ),
        ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.levels});

  final List<int> levels;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final level in levels) _LevelItem(level: level),
      ],
    );
  }
}
