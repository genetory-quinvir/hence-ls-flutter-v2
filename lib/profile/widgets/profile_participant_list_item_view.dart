import 'package:flutter/material.dart';

class ProfileParticipantListItemView extends StatelessWidget {
  const ProfileParticipantListItemView({
    super.key,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.fallbackUrl,
  });

  final String title;
  final String? subtitle;
  final String? thumbnailUrl;
  final String? fallbackUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Thumbnail(
            primaryUrl: thumbnailUrl,
            fallbackUrl: fallbackUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8E8E8E),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatefulWidget {
  const _Thumbnail({this.primaryUrl, this.fallbackUrl});

  final String? primaryUrl;
  final String? fallbackUrl;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  bool _useFallback = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryUrl?.trim() ?? '';
    final fallback = widget.fallbackUrl?.trim() ?? '';
    final activeUrl = _useFallback ? fallback : primary;
    final hasUrl = activeUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: hasUrl
            ? Image.network(
                activeUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  if (!_useFallback && fallback.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _useFallback = true);
                    });
                    return const SizedBox.shrink();
                  }
                  return _placeholder();
                },
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF2F2F2),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: Color(0xFF9E9E9E),
      ),
    );
  }
}
