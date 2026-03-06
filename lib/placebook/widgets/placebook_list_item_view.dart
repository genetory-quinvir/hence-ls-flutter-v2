import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:hence_ls_flutter_v2/main.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../common/widgets/common_image_view.dart';
import '../../common/widgets/common_inkwell.dart';

class PlacebookListItemView extends StatelessWidget {
  const PlacebookListItemView({
    super.key,
    required this.title,
    this.thumbnailUrl,
    this.address,
    this.commentCount,
    this.favoriteCount,
    this.isFavorited = false,
    this.onTap,
  });

  final String title;
  final String? thumbnailUrl;
  final String? address;
  final int? commentCount;
  final int? favoriteCount;
  final bool isFavorited;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? '장소' : title.trim();
    final safeAddress =
        (address ?? '').trim().isEmpty ? '장소 등록 안됨' : address!.trim();
    final rotationDegrees = _thumbnailRotationDegrees(safeTitle, safeAddress);
    const metaStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Color(0xFF757575),
    );
    return CommonInkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          width: 220,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.rotate(
                  angle: _degreesToRadians(rotationDegrees),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                    width: 60,
                    height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: ClipSmoothRect(
                          radius: SmoothBorderRadius(
                            cornerRadius: 8,
                            cornerSmoothing: 1,
                          ),
                          child: CommonImageView(
                            networkUrl: thumbnailUrl ?? '',
                            fit: BoxFit.cover,
                            backgroundColor: const Color(0xFFF2F2F2),
                          ),
                        ),
                      ),
                      if (isFavorited)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              PhosphorIconsFill.bookmarkSimple,
                            size: 12,
                            color: MyApp.primary200,
                          ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        safeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                        fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          safeAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metaStyle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                          const Icon(
                            PhosphorIconsBold.chatCircle,
                            size: 12,
                            color: Color(0xFF757575),
                          ),
                            const SizedBox(width: 4),
                            Text(
                              '${commentCount ?? 0}',
                              style: metaStyle,
                            ),
                            const SizedBox(width: 12),
                          const Icon(
                            PhosphorIconsBold.heart,
                            size: 12,
                            color: Color(0xFF757575),
                          ),
                            const SizedBox(width: 4),
                            Text(
                              '${favoriteCount ?? 0}',
                              style: metaStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _thumbnailRotationDegrees(String title, String address) {
    final seed = title.hashCode ^ address.hashCode;
    final magnitude = 2 + (seed.abs() % 4); // 2~5
    final sign = seed.isEven ? 1 : -1;
    return magnitude * sign.toDouble();
  }

  double _degreesToRadians(double degrees) =>
      degrees * (3.141592653589793 / 180);
}
