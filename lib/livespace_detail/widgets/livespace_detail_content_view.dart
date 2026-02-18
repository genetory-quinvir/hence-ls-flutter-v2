import 'package:flutter/material.dart';

class LivespaceDetailContentView extends StatelessWidget {
  const LivespaceDetailContentView({
    super.key,
    required this.content,
  });

  final String content;

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '어떤 라이브스페이스 인가요?',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
