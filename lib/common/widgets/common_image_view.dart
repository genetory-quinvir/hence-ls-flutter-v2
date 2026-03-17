import 'dart:collection';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

String _normalizeCacheKey(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;
  final normalized = uri.replace(query: '', fragment: '');
  return normalized.toString();
}

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
    this.replayNetworkFade = true,
    this.enableFade = true,
    this.disableFadeAfterFirstLoad = false,
    this.placeholderLogoSize = 24,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? networkUrl;
  final String? assetPath;
  final Uint8List? memoryBytes;
  final String? cacheKey;
  final BoxFit fit;
  final double blurSigma;
  final Color backgroundColor;
  final bool replayNetworkFade;
  final bool enableFade;
  final bool disableFadeAfterFirstLoad;
  final double placeholderLogoSize;
  final int? memCacheWidth;
  final int? memCacheHeight;

  static final _MemoryCache _cache = _MemoryCache(maxEntries: 200);
  static final Set<String> _loadedNetworkKeys = <String>{};
  static final Map<String, ImageProvider> _providerCache =
      <String, ImageProvider>{};
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'commonImageCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 500,
    ),
  );

  static Future<Uint8List?> fetchNetworkBytes(String url) {
    return _fetchFromNetwork(url);
  }

  static Future<void> prefetchNetworkUrls(Iterable<String> urls) async {
    final futures = <Future<Uint8List?>>[];
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isEmpty) continue;
      futures.add(_fetchFromNetwork(url));
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
  }

  static Future<Uint8List?> _fetchFromNetwork(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = response.bodyBytes;
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    if (image == null) return _placeholder();

    if (!enableFade || _isFadeSuppressed()) {
      return Container(
        color: backgroundColor,
        child: image,
      );
    }

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
    final networkKey = _networkKey();
    final normalizedKey = cacheKey == null ? null : _normalizeCacheKey(cacheKey!);
    final cachedBytes = normalizedKey == null ? null : _cache.get(normalizedKey);
    if (memoryBytes != null && memoryBytes!.isNotEmpty) {
      if (normalizedKey != null) {
        _cache.put(normalizedKey, memoryBytes!);
      }
      return Image.memory(
        memoryBytes!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      return Image.memory(
        cachedBytes,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    if (networkUrl != null && networkUrl!.trim().isNotEmpty) {
      if (disableFadeAfterFirstLoad && networkKey != null) {
        final cachedProvider = _providerCache[networkKey];
        if (cachedProvider != null) {
          return Image(
            image: cachedProvider,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          );
        }
      }
      final shouldFade = enableFade && !_isFadeSuppressed();
      final fadeIn = shouldFade
          ? (replayNetworkFade ? const Duration(milliseconds: 180) : Duration.zero)
          : Duration.zero;
      final fadeOut = shouldFade ? const Duration(milliseconds: 120) : Duration.zero;
      return CachedNetworkImage(
        imageUrl: networkUrl!.trim(),
        key: ValueKey(networkUrl!.trim()),
        cacheManager: _cacheManager,
        cacheKey: normalizedKey?.trim(),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fadeInDuration: fadeIn,
        fadeOutDuration: fadeOut,
        imageBuilder: (context, imageProvider) {
          if (disableFadeAfterFirstLoad && networkKey != null) {
            _loadedNetworkKeys.add(networkKey);
            _providerCache[networkKey] = imageProvider;
          }
          return Image(
            image: imageProvider,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          );
        },
        placeholder: (context, imageUrl) => _placeholder(),
        errorWidget: (context, imageUrl, error) => _placeholder(),
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
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    return null;
  }

  String? _networkKey() {
    final key = cacheKey == null ? null : _normalizeCacheKey(cacheKey!);
    if (key != null && key.isNotEmpty) return key;
    final url = networkUrl?.trim();
    if (url == null || url.isEmpty) return null;
    return _normalizeCacheKey(url);
  }

  bool _isFadeSuppressed() {
    if (!disableFadeAfterFirstLoad) return false;
    final key = _networkKey();
    if (key == null) return false;
    return _loadedNetworkKeys.contains(key);
  }

  Widget _placeholder() {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'assets/images/icon_logo.svg',
        width: placeholderLogoSize,
        height: placeholderLogoSize,
        colorFilter: ColorFilter.mode(const Color(0xFF9E9E9E), BlendMode.srcIn),
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
