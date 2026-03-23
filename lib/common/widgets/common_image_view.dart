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
    this.preferFadeOverMemoryCache = false,
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
  final bool preferFadeOverMemoryCache;

  static final _MemoryCache _cache = _MemoryCache(maxEntries: 200);
  static final Set<String> _loadedNetworkKeys = <String>{};
  static final Map<String, ImageProvider> _providerCache =
      <String, ImageProvider>{};
  static final BaseCacheManager _cacheManager = _CommonImageCacheManager();

  static Future<Uint8List?> fetchNetworkBytes(String url) {
    return _fetchFromNetwork(url);
  }

  static Future<void> prefetchNetworkUrls(Iterable<String> urls) async {
    final futures = <Future<Uint8List?>>[];
    for (final raw in urls) {
      final normalized = _normalizeCacheKey(raw);
      if (normalized.isEmpty) continue;
      if (_cache.get(normalized) != null) continue;
      futures.add(_fetchFromNetwork(normalized));
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
  }

  static Future<Uint8List?> _fetchFromNetwork(String url) async {
    final normalized = _normalizeCacheKey(url);
    final cached = _cache.get(normalized);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return null;
      _cache.put(normalized, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = _resolveMemCacheSize(context, constraints);
        final image = _buildImage(
          resolvedMemCacheWidth: resolved.width,
          resolvedMemCacheHeight: resolved.height,
        );
        if (image == null) return _placeholder();
        return Container(color: backgroundColor, child: image);
      },
    );
  }

  _ResolvedMemCacheSize _resolveMemCacheSize(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    int? toPx(double? logicalSize) {
      if (logicalSize == null ||
          logicalSize.isNaN ||
          logicalSize.isInfinite ||
          logicalSize <= 0) {
        return null;
      }
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      final px = (logicalSize * dpr).round();
      if (px < 16) return null;
      return px.clamp(16, 2048);
    }

    final inferredWidth = constraints.hasBoundedWidth
        ? toPx(constraints.maxWidth)
        : null;
    final inferredHeight = constraints.hasBoundedHeight
        ? toPx(constraints.maxHeight)
        : null;

    return _ResolvedMemCacheSize(
      width: memCacheWidth ?? inferredWidth,
      height: memCacheHeight ?? inferredHeight,
    );
  }

  Widget? _buildImage({
    int? resolvedMemCacheWidth,
    int? resolvedMemCacheHeight,
  }) {
    final networkKey = _networkKey();
    final normalizedNetworkUrl = networkUrl == null
        ? null
        : _normalizeCacheKey(networkUrl!.trim());
    final normalizedCacheKey = cacheKey == null
        ? null
        : _normalizeCacheKey(cacheKey!);
    final normalizedKey = normalizedCacheKey ?? normalizedNetworkUrl;
    final cachedBytes = normalizedKey == null
        ? null
        : _cache.get(normalizedKey);
    if (memoryBytes != null && memoryBytes!.isNotEmpty) {
      if (normalizedKey != null) {
        _cache.put(normalizedKey, memoryBytes!);
      }
      return Image.memory(
        memoryBytes!,
        fit: fit,
        filterQuality: FilterQuality.low,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    if (!preferFadeOverMemoryCache &&
        cachedBytes != null &&
        cachedBytes.isNotEmpty) {
      return Image.memory(
        cachedBytes,
        fit: fit,
        filterQuality: FilterQuality.low,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    if (networkUrl != null && networkUrl!.trim().isNotEmpty) {
      if (!enableFade && disableFadeAfterFirstLoad && networkKey != null) {
        final cachedProvider = _providerCache[networkKey];
        if (cachedProvider != null) {
          return Image(
            image: cachedProvider,
            fit: fit,
            filterQuality: FilterQuality.low,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          );
        }
      }
      final shouldFade =
          enableFade && (replayNetworkFade || !_isFadeSuppressed());
      return _NetworkDissolveImage(
        key: ValueKey(
          replayNetworkFade
              ? '${normalizedKey ?? networkUrl}-replay'
              : '${normalizedKey ?? networkUrl}-once',
        ),
        url: networkUrl!.trim(),
        cacheManager: _cacheManager,
        cacheKey: normalizedKey?.trim(),
        fit: fit,
        memCacheWidth: resolvedMemCacheWidth,
        memCacheHeight: resolvedMemCacheHeight,
        placeholder: _placeholder(),
        shouldFade: shouldFade,
        onImageResolved: (provider) {
          if (disableFadeAfterFirstLoad && networkKey != null) {
            _loadedNetworkKeys.add(networkKey);
            _providerCache[networkKey] = provider;
          }
        },
      );
    }
    if (assetPath != null && assetPath!.trim().isNotEmpty) {
      return Image.asset(
        assetPath!,
        key: ValueKey(assetPath),
        fit: fit,
        filterQuality: FilterQuality.low,
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

class _ResolvedMemCacheSize {
  const _ResolvedMemCacheSize({required this.width, required this.height});

  final int? width;
  final int? height;
}

class _NetworkDissolveImage extends StatefulWidget {
  const _NetworkDissolveImage({
    super.key,
    required this.url,
    required this.cacheManager,
    required this.cacheKey,
    required this.fit,
    required this.memCacheWidth,
    required this.memCacheHeight,
    required this.placeholder,
    required this.shouldFade,
    required this.onImageResolved,
  });

  final String url;
  final BaseCacheManager cacheManager;
  final String? cacheKey;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget placeholder;
  final bool shouldFade;
  final ValueChanged<ImageProvider> onImageResolved;

  @override
  State<_NetworkDissolveImage> createState() => _NetworkDissolveImageState();
}

class _NetworkDissolveImageState extends State<_NetworkDissolveImage> {
  bool _resolved = false;
  bool _failed = false;

  void _markResolved(ImageProvider provider) {
    if (_resolved || _failed || !mounted) return;
    widget.onImageResolved(provider);
    setState(() => _resolved = true);
  }

  @override
  Widget build(BuildContext context) {
    final canResizeWithCacheManager = widget.cacheManager is ImageCacheManager;
    final provider = CachedNetworkImageProvider(
      widget.url,
      cacheManager: widget.cacheManager,
      cacheKey: widget.cacheKey,
      maxWidth: canResizeWithCacheManager ? widget.memCacheWidth : null,
      maxHeight: canResizeWithCacheManager ? widget.memCacheHeight : null,
    );
    final image = Image(
      image: provider,
      fit: widget.fit,
      filterQuality: FilterQuality.low,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _markResolved(provider);
          });
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[CommonImageView] image_load_failed url=${widget.url} error=$error');
        if (!_failed && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _failed = true);
          });
        }
        return const SizedBox.shrink();
      },
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.placeholder,
        AnimatedOpacity(
          opacity: _resolved ? 1 : 0,
          duration: widget.shouldFade
              ? const Duration(milliseconds: 180)
              : Duration.zero,
          curve: Curves.easeOut,
          child: image,
        ),
      ],
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

class _CommonImageCacheManager extends CacheManager with ImageCacheManager {
  static const String _key = 'commonImageCache';
  static final _CommonImageCacheManager _instance =
      _CommonImageCacheManager._();

  factory _CommonImageCacheManager() => _instance;

  _CommonImageCacheManager._()
      : super(
          Config(
            _key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 500,
          ),
        );
}
