// import 'dart:typed_data';
// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:photo_manager/photo_manager.dart';

// import '../common/widgets/common_inkwell.dart';
// import '../common/widgets/common_image_view.dart';

// class FeedCreateInfoView extends StatefulWidget {
//   const FeedCreateInfoView({
//     super.key,
//     required this.selectedAssets,
//   });

//   final List<AssetEntity> selectedAssets;

//   @override
//   State<FeedCreateInfoView> createState() => _FeedCreateInfoViewState();
// }

// class _FeedCreateInfoViewState extends State<FeedCreateInfoView> {
//   final TextEditingController _textController = TextEditingController();
//   final FocusNode _textFocusNode = FocusNode();
//   bool _isEditingText = false;
//   int? _activeTextIndex;
//   int? _editingTextIndex;
//   String? _activeAssetId;
//   String? _editingAssetId;
//   Timer? _deselectTimer;
//   int _currentPageIndex = 0;
//   final Map<String, List<_TextOverlay>> _overlaysByAsset = {};
//   Offset _startFocalPoint = Offset.zero;
//   Offset _startOffset = Offset.zero;
//   double _startScale = 1.0;
//   double _startRotation = 0.0;
//   Offset _lastFocalPoint = Offset.zero;
//   double _lastScale = 1.0;
//   double _lastRotation = 0.0;

//   static const List<double> _fontSizes = [20, 24, 28];
//   static const List<Color> _textColors = [
//     Colors.white,
//     Colors.black,
//     Color(0xFFFF5252),
//     Color(0xFF4CAF50),
//     Color(0xFF448AFF),
//   ];
//   static const List<Color> _bgColors = [
//     Color(0xFF212121),
//     Color(0xFF424242),
//     Color(0xFFFFF59D),
//     Color(0xFFFFCDD2),
//     Color(0xFFC8E6C9),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
//   }

//   @override
//   void dispose() {
//     _deselectTimer?.cancel();
//     _textController.dispose();
//     _textFocusNode.dispose();
//     SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
//     super.dispose();
//   }

//   String? _currentAssetId() {
//     if (widget.selectedAssets.isEmpty) return null;
//     final index = _currentPageIndex.clamp(0, widget.selectedAssets.length - 1);
//     return widget.selectedAssets[index].id;
//   }

//   List<_TextOverlay> _overlaysForAsset(String assetId) {
//     return _overlaysByAsset.putIfAbsent(assetId, () => []);
//   }

//   void _startTextEditing() {
//     final assetId = _currentAssetId();
//     if (assetId == null) return;
//     final overlay = _TextOverlay();
//     final overlays = _overlaysForAsset(assetId);
//     overlays.add(overlay);
//     _activeAssetId = assetId;
//     _activeTextIndex = overlays.length - 1;
//     _editingAssetId = assetId;
//     _editingTextIndex = _activeTextIndex;
//     _textController.text = '';
//     setState(() => _isEditingText = true);
//     _textFocusNode.requestFocus();
//   }

//   void _stopTextEditing() {
//     if (_editingTextIndex != null && _editingAssetId != null) {
//       final overlays = _overlaysByAsset[_editingAssetId!];
//       if (overlays != null && _editingTextIndex! < overlays.length) {
//         final text = _textController.text.trim();
//         if (text.isEmpty) {
//           overlays.removeAt(_editingTextIndex!);
//           if (_activeAssetId == _editingAssetId &&
//               _activeTextIndex == _editingTextIndex) {
//             _activeTextIndex = null;
//             _activeAssetId = null;
//           }
//         } else {
//           overlays[_editingTextIndex!].text = text;
//         }
//       }
//     }
//     _editingTextIndex = null;
//     _editingAssetId = null;
//     setState(() => _isEditingText = false);
//     _textFocusNode.unfocus();
//   }

//   void _selectText(String assetId, int index) {
//     _activeAssetId = assetId;
//     _activeTextIndex = index;
//     setState(() {});
//     _deselectTimer?.cancel();
//   }

//   void _clearTextSelection() {
//     _activeTextIndex = null;
//     _activeAssetId = null;
//     setState(() {});
//     _deselectTimer?.cancel();
//   }

//   void _bringForward() {
//     if (_activeTextIndex == null || _activeAssetId == null) return;
//     final overlays = _overlaysByAsset[_activeAssetId!];
//     if (overlays == null) return;
//     final index = _activeTextIndex!;
//     if (index >= overlays.length - 1) return;
//     final temp = overlays[index + 1];
//     overlays[index + 1] = overlays[index];
//     overlays[index] = temp;
//     _activeTextIndex = index + 1;
//     setState(() {});
//   }

//   void _sendBackward() {
//     if (_activeTextIndex == null || _activeAssetId == null) return;
//     final overlays = _overlaysByAsset[_activeAssetId!];
//     if (overlays == null) return;
//     final index = _activeTextIndex!;
//     if (index <= 0) return;
//     final temp = overlays[index - 1];
//     overlays[index - 1] = overlays[index];
//     overlays[index] = temp;
//     _activeTextIndex = index - 1;
//     setState(() {});
//   }

//   void _deleteActiveText() {
//     if (_activeTextIndex == null || _activeAssetId == null) return;
//     final overlays = _overlaysByAsset[_activeAssetId!];
//     if (overlays == null) return;
//     final index = _activeTextIndex!;
//     if (index < 0 || index >= overlays.length) return;
//     overlays.removeAt(index);
//     _clearTextSelection();
//   }

//   _TextOverlay? _activeOverlay() {
//     if (_activeTextIndex == null || _activeAssetId == null) return null;
//     final overlays = _overlaysByAsset[_activeAssetId!];
//     if (overlays == null) return null;
//     if (_activeTextIndex! < 0 || _activeTextIndex! >= overlays.length) return null;
//     return overlays[_activeTextIndex!];
//   }

//   void _cycleFontSize() {
//     final overlay = _activeOverlay();
//     if (overlay == null) return;
//     final index = _fontSizes.indexOf(overlay.fontSize);
//     final next = _fontSizes[(index + 1) % _fontSizes.length];
//     setState(() => overlay.fontSize = next);
//   }

//   void _cycleTextColor() {
//     final overlay = _activeOverlay();
//     if (overlay == null) return;
//     final index = _textColors.indexOf(overlay.textColor);
//     final next = _textColors[(index + 1) % _textColors.length];
//     setState(() => overlay.textColor = next);
//   }

//   void _toggleBackground() {
//     final overlay = _activeOverlay();
//     if (overlay == null) return;
//     setState(() {
//       if (overlay.backgroundColor == null) {
//         overlay.backgroundColor = _bgColors.first;
//       } else {
//         final index = _bgColors.indexOf(overlay.backgroundColor!);
//         final next = _bgColors[(index + 1) % _bgColors.length];
//         overlay.backgroundColor = next;
//       }
//     });
//   }

//   Widget _buildMenuButton({
//     required IconData icon,
//     required String label,
//     VoidCallback? onTap,
//   }) {
//     return CommonInkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(6),
//       child: Opacity(
//         opacity: onTap == null ? 0.5 : 1.0,
//         child: Container(
//           padding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 10,
//           ),
//           decoration: BoxDecoration(
//             color: const Color(0xFF212121),
//             borderRadius: BorderRadius.circular(6),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(
//                 icon,
//                 size: 18,
//                 color: Colors.white,
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 label,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.white,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   List<Widget> _menuButtons() {
//     if (_activeTextIndex == null) {
//       return [
//         _buildMenuButton(
//           icon: Icons.text_fields,
//           label: '텍스트',
//           onTap: _startTextEditing,
//         ),
//         _buildMenuButton(
//           icon: Icons.layers_outlined,
//           label: '오버레이',
//           onTap: () {},
//         ),
//         _buildMenuButton(
//           icon: Icons.flip_to_front,
//           label: '앞으로',
//           onTap: _activeTextIndex == null ? null : _bringForward,
//         ),
//         _buildMenuButton(
//           icon: Icons.flip_to_back,
//           label: '뒤로',
//           onTap: _activeTextIndex == null ? null : _sendBackward,
//         ),
//         _buildMenuButton(
//           icon: Icons.delete_outline,
//           label: '삭제',
//           onTap: _activeTextIndex == null ? null : _deleteActiveText,
//         ),
//       ];
//     }
//     return [
//       _buildMenuButton(
//         icon: Icons.format_size,
//         label: '폰트',
//         onTap: _cycleFontSize,
//       ),
//       _buildMenuButton(
//         icon: Icons.palette_outlined,
//         label: '텍스트',
//         onTap: _cycleTextColor,
//       ),
//       _buildMenuButton(
//         icon: Icons.format_color_fill,
//         label: '배경',
//         onTap: _toggleBackground,
//       ),
//       _buildMenuButton(
//         icon: Icons.delete_outline,
//         label: '삭제',
//         onTap: _activeTextIndex == null ? null : _deleteActiveText,
//       ),
//     ];
//   }

//   List<Widget> _withSpacing(List<Widget> items, double spacing) {
//     if (items.isEmpty) return [];
//     final spaced = <Widget>[];
//     for (var i = 0; i < items.length; i++) {
//       spaced.add(items[i]);
//       if (i != items.length - 1) {
//         spaced.add(SizedBox(width: spacing));
//       }
//     }
//     return spaced;
//   }

//   void _scheduleDeselect() {
//     _deselectTimer?.cancel();
//     _deselectTimer = Timer(const Duration(seconds: 3), () {
//       if (mounted) {
//         _activeTextIndex = null;
//         setState(() {});
//       }
//     });
//   }

//   void _onTextScaleStart(ScaleStartDetails details) {
//     if (_activeTextIndex == null || _activeAssetId == null) return;
//     final overlays = _overlaysByAsset[_activeAssetId!];
//     if (overlays == null || _activeTextIndex! >= overlays.length) return;
//     final overlay = overlays[_activeTextIndex!];
//     _startFocalPoint = details.focalPoint;
//     _startOffset = overlay.offset;
//     _startScale = overlay.scale;
//     _startRotation = overlay.rotation;
//     _lastFocalPoint = details.focalPoint;
//     _lastScale = 1.0;
//     _lastRotation = 0.0;
//   }

//   void _onTextScaleUpdate(ScaleUpdateDetails details) {
//     if (_activeTextIndex == null || _activeAssetId == null) return;
//     final overlays = _overlaysByAsset[_activeAssetId!];
//     if (overlays == null || _activeTextIndex! >= overlays.length) return;
//     final overlay = overlays[_activeTextIndex!];
//     setState(() {
//       final delta = details.focalPoint - _lastFocalPoint;
//       overlay.offset += delta;
//       if (details.scale != 0 && _lastScale != 0) {
//         overlay.scale =
//             (overlay.scale * (details.scale / _lastScale)).clamp(0.5, 4.0);
//       }
//       overlay.rotation += details.rotation - _lastRotation;
//       _lastFocalPoint = details.focalPoint;
//       _lastScale = details.scale;
//       _lastRotation = details.rotation;
//     });
//   }

//   void _onTextScaleEnd(ScaleEndDetails details) {
//     _scheduleDeselect();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Column(
//         children: [
//           SafeArea(
//             bottom: false,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: SizedBox(
//                 height: 48,
//                 child: Row(
//                   children: [
//                     CommonInkWell(
//                       onTap: () => Navigator.of(context).maybePop(),
//                       child: const Icon(
//                         Icons.arrow_back_ios_new,
//                         size: 20,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const Spacer(),
//                     CommonInkWell(
//                       onTap: () {},
//                       child: const Text(
//                         '다음',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           Expanded(
//             child: LayoutBuilder(
//               builder: (context, constraints) {
//                 final screen = MediaQuery.of(context).size;
//                 final bottomInset = MediaQuery.of(context).padding.bottom;
//                 final cardWidth = screen.width - 32;
//                 final cardHeight = cardWidth * (5 / 4);
//                 const menuHeight = 56.0;
//                 final hasPhotos = widget.selectedAssets.isNotEmpty;
//                 final contentHeight =
//                     (hasPhotos ? (16 + cardHeight) : 0) + 48 + menuHeight;
//                 final availableHeight = constraints.maxHeight - bottomInset;
//                 final topSpacer = (availableHeight - contentHeight) > 0
//                     ? (availableHeight - contentHeight) / 2
//                     : 0.0;

//                 return Column(
//                   children: [
//                     SizedBox(height: topSpacer),
//                     if (hasPhotos) ...[
//                       const SizedBox(height: 16),
//                       SizedBox(
//                         height: cardHeight,
//                         child: PageView.builder(
//                           controller: PageController(
//                             viewportFraction: cardWidth / screen.width,
//                           ),
//                           onPageChanged: (index) {
//                             _currentPageIndex = index;
//                             _clearTextSelection();
//                             if (_isEditingText) {
//                               _stopTextEditing();
//                             }
//                           },
//                           physics: const PageScrollPhysics(),
//                           itemCount: widget.selectedAssets.length,
//                           itemBuilder: (context, index) {
//                             final asset = widget.selectedAssets[index];
//                             final overlays =
//                                 _overlaysByAsset[asset.id] ?? <_TextOverlay>[];
//                             final isActiveCard = _activeAssetId == asset.id;
//                             final activeIndex =
//                                 isActiveCard ? _activeTextIndex : null;
//                             return Padding(
//                               padding:
//                                   const EdgeInsets.symmetric(horizontal: 16),
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.circular(12),
//                                 child: Stack(
//                                   fit: StackFit.expand,
//                                   children: [
//                                     GestureDetector(
//                                       behavior: HitTestBehavior.translucent,
//                                       onTap: _clearTextSelection,
//                                       onScaleStart: activeIndex != null && !_isEditingText
//                                           ? _onTextScaleStart
//                                           : null,
//                                       onScaleUpdate: activeIndex != null && !_isEditingText
//                                           ? _onTextScaleUpdate
//                                           : null,
//                                       onScaleEnd: activeIndex != null && !_isEditingText
//                                           ? _onTextScaleEnd
//                                           : null,
//                                       child: _SelectedPreview(asset: asset),
//                                     ),
//                                     for (var i = 0; i < overlays.length; i++)
//                                       Positioned.fill(
//                                           child: GestureDetector(
//                                             onTap: () {
//                                               _selectText(asset.id, i);
//                                             },
//                                             onScaleStart: (details) {
//                                               _selectText(asset.id, i);
//                                               _onTextScaleStart(details);
//                                           },
//                                           onScaleUpdate: _onTextScaleUpdate,
//                                           onScaleEnd: _onTextScaleEnd,
//                                           child: Center(
//                                             child: Transform.translate(
//                                               offset: overlays[i].offset,
//                                               child: Transform.rotate(
//                                                 angle: overlays[i].rotation,
//                                                 child: Transform.scale(
//                                                   scale: overlays[i].scale,
//                                                     child: Opacity(
//                                                     opacity: activeIndex == null
//                                                         ? 1.0
//                                                         : (activeIndex == i ? 1.0 : 0.7),
//                                                     child: Builder(
//                                                       builder: (context) {
//                                                         final textStyle = TextStyle(
//                                                           fontSize: overlays[i].fontSize,
//                                                           fontWeight: FontWeight.w700,
//                                                           color: overlays[i].textColor,
//                                                         );
//                                                         final painter = TextPainter(
//                                                           text: TextSpan(
//                                                             text: overlays[i].text,
//                                                             style: textStyle,
//                                                           ),
//                                                           textDirection: TextDirection.ltr,
//                                                         )..layout();
//                                                         const padding = EdgeInsets.symmetric(
//                                                           horizontal: 8,
//                                                           vertical: 4,
//                                                         );
//                                                         final width =
//                                                             painter.width + padding.horizontal;
//                                                         final height =
//                                                             painter.height + padding.vertical;
//                                                         return SizedBox(
//                                                           width: width,
//                                                           height: height,
//                                                           child: Container(
//                                                             padding: padding,
//                                                             decoration: BoxDecoration(
//                                                               color:
//                                                                   overlays[i].backgroundColor,
//                                                               borderRadius:
//                                                                   BorderRadius.circular(6),
//                                                             ),
//                                                             child: Text(
//                                                               overlays[i].text,
//                                                               textAlign: TextAlign.center,
//                                                               style: textStyle,
//                                                             ),
//                                                           ),
//                                                         );
//                                                       },
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     if (_isEditingText &&
//                                         _editingAssetId == asset.id)
//                                       Positioned.fill(
//                                         child: GestureDetector(
//                                           onTap: _stopTextEditing,
//                                           child: Container(
//                                             color: Colors.black.withOpacity(0.35),
//                                             alignment: Alignment.center,
//                                             padding:
//                                                 const EdgeInsets.symmetric(horizontal: 24),
//                                             child: TextField(
//                                               controller: _textController,
//                                               focusNode: _textFocusNode,
//                                               textAlign: TextAlign.center,
//                                               style: const TextStyle(
//                                                 fontSize: 24,
//                                                 fontWeight: FontWeight.w700,
//                                                 color: Colors.white,
//                                               ),
//                                               decoration: const InputDecoration(
//                                                 hintText: '텍스트 입력',
//                                                 hintStyle: TextStyle(
//                                                   color: Colors.white54,
//                                                   fontSize: 24,
//                                                   fontWeight: FontWeight.w700,
//                                                 ),
//                                                 border: InputBorder.none,
//                                               ),
//                                               onSubmitted: (_) => _stopTextEditing(),
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     // grid guide removed
//                                     if (activeIndex != null)
//                                       Positioned.fill(
//                                         child: IgnorePointer(
//                                           child: CustomPaint(
//                                             painter: _HandlePainter(),
//                                           ),
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ],
//                     const SizedBox(height: 48),
//                     SizedBox(
//                       height: menuHeight,
//                       child: Center(
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 16),
//                           child: FittedBox(
//                             fit: BoxFit.scaleDown,
//                             alignment: Alignment.center,
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: _withSpacing(_menuButtons(), 8),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                     SizedBox(height: bottomInset),
//                   ],
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _AssetThumbnail extends StatelessWidget {
//   const _AssetThumbnail({required this.asset});

//   final AssetEntity asset;

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<Uint8List?>(
//       future: asset.thumbnailDataWithSize(const ThumbnailSize(600, 600)),
//       builder: (context, snapshot) {
//         final bytes = snapshot.data;
//         if (bytes == null) {
//           return Container(color: const Color(0xFFE0E0E0));
//         }
//         return CommonImageView(
//           memoryBytes: bytes,
//           cacheKey: '${asset.id}_600',
//           fit: BoxFit.cover,
//           backgroundColor: Colors.black,
//         );
//       },
//     );
//   }
// }

// class _SelectedPreview extends StatelessWidget {
//   const _SelectedPreview({required this.asset});

//   final AssetEntity asset;

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<Uint8List?>(
//       future: asset.thumbnailDataWithSize(const ThumbnailSize(1600, 1600)),
//       builder: (context, snapshot) {
//         final bytes = snapshot.data;
//         if (bytes == null) {
//           return Container(color: const Color.fromARGB(255, 0, 0, 0));
//         }
//         return CommonImageView(
//           memoryBytes: bytes,
//           cacheKey: '${asset.id}_1600',
//           fit: BoxFit.cover,
//           backgroundColor: Colors.black,
//         );
//       },
//     );
//   }
// }

// class _HandlePainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     const handleSize = 8.0;
//     final paint = Paint()
//       ..color = Colors.white
//       ..style = PaintingStyle.fill;
//     final points = [
//       Offset(0, 0),
//       Offset(size.width, 0),
//       Offset(0, size.height),
//       Offset(size.width, size.height),
//     ];
//     for (final p in points) {
//       canvas.drawCircle(p, handleSize / 2, paint);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }

// class _TextOverlay {
//   _TextOverlay({
//     this.text = '',
//     this.offset = Offset.zero,
//     this.scale = 1.0,
//     this.rotation = 0.0,
//     this.fontSize = 24,
//     this.textColor = Colors.white,
//     this.backgroundColor,
//   });

//   String text;
//   Offset offset;
//   double scale;
//   double rotation;
//   double fontSize;
//   Color textColor;
//   Color? backgroundColor;
// }
