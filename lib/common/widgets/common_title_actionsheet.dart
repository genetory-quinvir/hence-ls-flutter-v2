import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'common_inkwell.dart';

class CommonTitleActionSheet extends StatelessWidget {
  const CommonTitleActionSheet({
    super.key,
    required this.title,
    required this.items,
    this.onSelected,
  });

  final String title;
  final List<CommonTitleActionSheetItem> items;
  final ValueChanged<CommonTitleActionSheetItem>? onSelected;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<CommonTitleActionSheetItem> items,
    ValueChanged<CommonTitleActionSheetItem>? onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: CommonTitleActionSheet(
            title: title,
            items: items,
            onSelected: (value) {
              Navigator.of(context).pop();
              onSelected?.call(value);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
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
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox.shrink(),
            itemBuilder: (context, index) {
              final item = items[index];
              return CommonInkWell(
                onTap: () => onSelected?.call(item),
                child: SizedBox(
                  height: 50,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: item.isDestructive
                            ? const Color(0xFFE53935)
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CommonTitleActionSheetItem {
  const CommonTitleActionSheetItem({
    required this.label,
    this.isDestructive = false,
    this.value,
  });

  final String label;
  final bool isDestructive;
  final String? value;
}
