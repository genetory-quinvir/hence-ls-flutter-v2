import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:collection';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

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
    this.placeholderLogoSize = 24,
  });

  final String? networkUrl;
  final String? assetPath;
  final Uint8List? memoryBytes;
  final String? cacheKey;
  final BoxFit fit;
  final double blurSigma;
  final Color backgroundColor;
  final bool replayNetworkFade;
  final double placeholderLogoSize;

  static final _MemoryCache _cache = _MemoryCache(maxEntries: 200);
  static Future<Uint8List?> fetchNetworkBytes(String url) {
    return _NetworkImageCache.fetch(url);
  }

  static Future<void> prefetchNetworkUrls(Iterable<String> urls) async {
    final futures = <Future<Uint8List?>>[];
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isEmpty) continue;
      futures.add(_NetworkImageCache.fetch(url));
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
  }

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
      return _NetworkCachedImage(
        url: networkUrl!.trim(),
        fit: fit,
        replayFade: replayNetworkFade,
        placeholderBuilder: _placeholder,
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
        'assets/images/icon_logo.svg',
        width: placeholderLogoSize,
        height: placeholderLogoSize,
        colorFilter: ColorFilter.mode(
          const Color(0xFF9E9E9E),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _NetworkCachedImage extends StatefulWidget {
  const _NetworkCachedImage({
    required this.url,
    required this.fit,
    required this.replayFade,
    required this.placeholderBuilder,
  });

  final String url;
  final BoxFit fit;
  final bool replayFade;
  final Widget Function() placeholderBuilder;

  @override
  State<_NetworkCachedImage> createState() => _NetworkCachedImageState();
}

class _NetworkCachedImageState extends State<_NetworkCachedImage> {
  Future<Uint8List?>? _future;
  Uint8List? _immediateBytes;
  bool _shouldAnimate = false;
  static final Set<String> _shownUrls = <String>{};

  @override
  void initState() {
    super.initState();
    _resolveSource();
  }

  @override
  void didUpdateWidget(covariant _NetworkCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.replayFade != widget.replayFade) {
      _resolveSource();
    }
  }

  void _resolveSource() {
    final shownBefore = _shownUrls.contains(widget.url);
    final cached = _NetworkImageCache.get(widget.url);
    if (cached != null && cached.isNotEmpty) {
      _immediateBytes = cached;
      _shouldAnimate = !shownBefore || widget.replayFade;
      _future = Future.value(cached);
      return;
    }
    _immediateBytes = null;
    _shouldAnimate = !shownBefore || widget.replayFade;
    _future = _NetworkImageCache.fetch(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    if (_immediateBytes != null) {
      return _buildImage(_immediateBytes!, animate: _shouldAnimate);
    }
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return widget.placeholderBuilder();
        }
        return _buildImage(bytes, animate: _shouldAnimate);
      },
    );
  }

  Widget _buildImage(Uint8List bytes, {required bool animate}) {
    final image = Image.memory(
      bytes,
      key: ValueKey(widget.url),
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => widget.placeholderBuilder(),
    );
    if (!animate) {
      _shownUrls.add(widget.url);
      return image;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      onEnd: () {
        _shownUrls.add(widget.url);
      },
      builder: (context, opacity, fadedChild) {
        return Opacity(opacity: opacity, child: fadedChild);
      },
      child: image,
    );
  }
}

class _NetworkImageCache {
  _NetworkImageCache._();

  static final _MemoryCache _bytes = _MemoryCache(maxEntries: 1200);
  static final Map<String, Future<Uint8List?>> _inflight = {};

  static Uint8List? get(String url) => _bytes.get(url);

  static Future<Uint8List?> fetch(String url) {
    final cached = _bytes.get(url);
    if (cached != null && cached.isNotEmpty) {
      return Future.value(cached);
    }
    final pending = _inflight[url];
    if (pending != null) return pending;

    final future = _download(url);
    _inflight[url] = future;
    future.whenComplete(() => _inflight.remove(url));
    return future;
  }

  static Future<Uint8List?> _download(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return null;
      _bytes.put(url, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
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
