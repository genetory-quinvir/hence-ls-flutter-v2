import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../common/widgets/common_inkwell.dart';
import '../common/widgets/common_rounded_button.dart';
import '../common/widgets/common_textfield_view.dart';

class ReportView extends StatefulWidget {
  const ReportView({
    super.key,
    this.placeId,
  });

  final String? placeId;

  static Future<void> show(
    BuildContext context, {
    String? placeId,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (_) => ReportView(placeId: placeId),
    );
  }

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  static const _reasons = <Map<String, String>>[
    {'value': 'spam', 'label': '스팸/도배'},
    {'value': 'inappropriate', 'label': '부적절한 내용'},
    {'value': 'false_information', 'label': '허위 정보'},
    {'value': 'copyright', 'label': '저작권 침해'},
    {'value': 'other', 'label': '기타'},
  ];

  final TextEditingController _detailController = TextEditingController();
  String? _selectedReason;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedReason == null || _selectedReason!.isEmpty) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _selectedReason != null && _selectedReason!.isNotEmpty;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          '신고하기',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '닫기',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
      ),
      child: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '신고 사유',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                ..._reasons.map((reason) {
                  final value = reason['value'] ?? '';
                  final label = reason['label'] ?? '';
                  final selected = value == _selectedReason;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CommonInkWell(
                      onTap: () => setState(() => _selectedReason = value),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF111111)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      selected ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  '상세 내용 (선택)',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                CommonTextFieldView(
                  controller: _detailController,
                  hintText: '추가로 전달할 내용을 입력해주세요.',
                  maxLines: 4,
                  maxLength: 200,
                  textInputAction: TextInputAction.newline,
                  backgroundColor: const Color(0xFFF5F5F5),
                ),
                const Spacer(),
                CommonRoundedButton(
                  title: '신고하기',
                  height: 52,
                  radius: 14,
                  onTap: canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
