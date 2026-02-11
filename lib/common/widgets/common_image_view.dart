import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:collection';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommonImageView extends StatelessWidget {
  const CommonImageView({
    super.key,
    this.networkUrl,
    this.assetPath,
    this.memoryBytes,
    this.cacheKey,
    this.fit = BoxFit.contain,
    this.blurSigma = 8,
    this.backgroundColor = Colors.transparent,
  });

  final String? networkUrl;
  final String? assetPath;
  final Uint8List? memoryBytes;
  final String? cacheKey;
  final BoxFit fit;
  final double blurSigma;
  final Color backgroundColor;

  static final _MemoryCache _cache = _MemoryCache(maxEntries: 200);

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    if (image == null) return _placeholder();

    return Container(
      color: backgroundColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: image,
      ),
    );
  }

  Widget? _buildImage() {
    final cachedBytes = cacheKey == null ? null : _cache.get(cacheKey!);
    if (memoryBytes != null && memoryBytes!.isNotEmpty) {
      if (cacheKey != null) {
        _cache.put(cacheKey!, memoryBytes!);
      }
      return Image.memory(
        memoryBytes!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      return Image.memory(
        cachedBytes,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (networkUrl != null && networkUrl!.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 200),
        placeholderFadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    if (assetPath != null && assetPath!.trim().isNotEmpty) {
      return Image.asset(
        assetPath!,
        key: ValueKey(assetPath),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return null;
  }

  Widget _placeholder() {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'lib/assets/images/icon_logo.svg',
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          const Color(0xFF9E9E9E),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _MemoryCache {
  _MemoryCache({required this.maxEntries});

  final int maxEntries;
  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap();

  Uint8List? get(String key) {
    final value = _map.remove(key);
    if (value == null) return null;
    _map[key] = value;
    return value;
  }

  void put(String key, Uint8List value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    }
    _map[key] = value;
    if (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
  }
}
