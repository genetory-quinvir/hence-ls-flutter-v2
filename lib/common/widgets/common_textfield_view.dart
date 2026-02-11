import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CommonTextFieldView extends StatefulWidget {
  const CommonTextFieldView({
    super.key,
    this.controller,
    this.focusNode,
    this.title,
    this.hintText,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? title;
  final String? hintText;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<CommonTextFieldView> createState() => _CommonTextFieldViewState();
}

class _CommonTextFieldViewState extends State<CommonTextFieldView> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _ownsController;
  late bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsController = widget.controller == null;
    _ownsFocusNode = widget.focusNode == null;
    _controller.addListener(_handleChange);
    _focusNode.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant CommonTextFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleChange);
      if (_ownsController) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TextEditingController();
      _ownsController = widget.controller == null;
      _controller.addListener(_handleChange);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleChange);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    _focusNode.removeListener(_handleChange);
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearText() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final showClear = _focusNode.hasFocus && _controller.text.isNotEmpty;
    final hasTitle = widget.title != null && widget.title!.trim().isNotEmpty;
    final showHeader = hasTitle;
    final showCounter = showHeader && widget.maxLength != null;
    final currentLength = _controller.text.length;

    const double containerHeight = 76;
    const double containerHeightNoTitle = 50;
    const double headerHeight = 20;
    const double inputHeight = 44;
    const double headerGap = 4;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: showHeader ? containerHeight : containerHeightNoTitle,
        child: showHeader
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    height: headerHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ),
                        if (showCounter)
                          Text(
                            '$currentLength/${widget.maxLength}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF757575),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: headerGap),
                  SizedBox(
                    height: inputHeight,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: widget.maxLines,
                      maxLength: widget.maxLength,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: widget.onChanged,
                      enabled: widget.enabled,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        counterText: '',
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 36,
                        ),
                        suffixIcon: Visibility(
                          visible: showClear,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: InkWell(
                            onTap: showClear ? _clearText : null,
                            customBorder: const CircleBorder(),
                            child: const Icon(
                              PhosphorIconsFill.xCircle,
                              size: 20,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: SizedBox(
                  height: inputHeight,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: widget.maxLines,
                    maxLength: widget.maxLength,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: widget.onChanged,
                    enabled: widget.enabled,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      counterText: '',
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 36,
                      ),
                      suffixIcon: Visibility(
                        visible: showClear,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: InkWell(
                          onTap: showClear ? _clearText : null,
                          customBorder: const CircleBorder(),
                          child: const Icon(
                            PhosphorIconsFill.xCircle,
                            size: 20,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
