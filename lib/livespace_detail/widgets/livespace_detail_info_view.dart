import 'package:flutter/material.dart';

class LivespaceDetailInfoView extends StatelessWidget {
  const LivespaceDetailInfoView({
    super.key,
    required this.title,
    required this.place,
    required this.time,
    required this.status,
  });

  final String title;
  final String place;
  final String time;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        ],
      ),
    );
  }
}
