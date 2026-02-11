import 'dart:convert';

import 'package:http/http.dart' as http;

class NaverLocationService {
  NaverLocationService._();

  static const String _clientId = 'e2m4s9kqcr';
  static const String _clientSecret = 'de8S9JuDyztJIIW0XmxT43UJErIC2j6a6esfJa5Y';

  static Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final coords = '$longitude,$latitude';
    final uri = Uri.parse('https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc')
        .replace(queryParameters: {
      'coords': coords,
      'output': 'json',
      'sourcecrs': 'EPSG:4326',
      'orders': 'legalcode,admcode,addr,roadaddr',
    });

    final response = await http.get(uri, headers: {
      'x-ncp-apigw-api-key-id': _clientId,
      'x-ncp-apigw-api-key': _clientSecret,
      'Accept': 'application/json',
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;
    final results = json['results'];
    if (results is! List || results.isEmpty) return null;

    final primary = results.firstWhere(
      (item) => item is Map<String, dynamic>,
      orElse: () => null,
    );
    if (primary is! Map<String, dynamic>) return null;

    final region = primary['region'];
    if (region is Map<String, dynamic>) {
      final area1 = region['area1'] as Map<String, dynamic>?;
      final area2 = region['area2'] as Map<String, dynamic>?;
      final area3 = region['area3'] as Map<String, dynamic>?;
      final area4 = region['area4'] as Map<String, dynamic>?;
      final parts = [
        area1?['name'],
        area2?['name'],
        area3?['name'],
        area4?['name'],
      ].whereType<String>().where((v) => v.trim().isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.join(' ');
    }

    final land = primary['land'];
    if (land is Map<String, dynamic>) {
      final name = land['name'];
      if (name is String && name.trim().isNotEmpty) return name;
    }

    return null;
  }
}
