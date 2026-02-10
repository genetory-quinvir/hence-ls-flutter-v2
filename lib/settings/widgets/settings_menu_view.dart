import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../common/widgets/common_inkwell.dart';

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSectionDivider extends StatelessWidget {
  const SettingsSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 8,
            color: Colors.white,
          ),
          Container(
            width: double.infinity,
            height: 12,
            color: Color(0xFFF5F5F5),
          ),
        ],
      ),
    );
  }
}

class SettingsMenuRow extends StatelessWidget {
  const SettingsMenuRow({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
  });

  factory SettingsMenuRow.action({
    required String title,
    required VoidCallback onTap,
  }) {
    return SettingsMenuRow(
      title: title,
      onTap: onTap,
      trailing: const Icon(
        PhosphorIconsRegular.caretRight,
        size: 16,
        color: Colors.black,
      ),
    );
  }

  factory SettingsMenuRow.value({
    required String title,
    required String value,
  }) {
    return SettingsMenuRow(
      title: title,
      trailing: Text(
        value,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF9E9E9E),
        ),
      ),
    );
  }

  factory SettingsMenuRow.segment({
    required String title,
    required List<String> segments,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return SettingsMenuRow(
      title: title,
      trailing: CupertinoSegmentedControl<int>(
        groupValue: selectedIndex,
        onValueChanged: onChanged,
        children: {
          for (var i = 0; i < segments.length; i++)
            i: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                segments[i],
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        },
      ),
    );
  }

  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = _RowBase(title: title, trailing: trailing);
    if (onTap == null) return row;
    return CommonInkWell(onTap: onTap, child: row);
  }
}

class _RowBase extends StatelessWidget {
  const _RowBase({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
