import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class MediaConversionService {
  MediaConversionService._();

  static Future<File> toWebp(File input, {int quality = 85}) async {
    final targetPath = _buildTargetPath(input.path);

    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      targetPath,
      format: CompressFormat.webp,
      quality: quality,
    );

    if (result == null) return input;
    return File(result.path);
  }

  static String _buildTargetPath(String inputPath) {
    final filename = 'feed_${DateTime.now().microsecondsSinceEpoch}.webp';
    final fallback = '${Directory.systemTemp.path}/$filename';
    try {
      final parent = File(inputPath).parent;
      if (parent.path.isEmpty) return fallback;
      return '${parent.path}/$filename';
    } catch (_) {
      return fallback;
    }
  }
}
