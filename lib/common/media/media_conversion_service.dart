import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class MediaConversionService {
  MediaConversionService._();

  static Future<File> toWebp(File input, {int quality = 85}) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.webp';

    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      targetPath,
      format: CompressFormat.webp,
      quality: quality,
    );

    if (result == null) return input;
    return File(result.path);
  }
}
