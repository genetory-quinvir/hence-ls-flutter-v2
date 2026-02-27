import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlacebookCache {
  PlacebookCache._();

  static const String _categoriesKey = 'placebook.categories';
  static const String _themesKey = 'placebook.themes';
  static const String _categoriesUpdatedKey = 'placebook.categories.updatedAt';
  static const String _themesUpdatedKey = 'placebook.themes.updatedAt';

  static Future<void> saveCategories(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesKey, jsonEncode(items));
    await prefs.setString(_categoriesUpdatedKey, DateTime.now().toIso8601String());
  }

  static Future<void> saveThemes(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themesKey, jsonEncode(items));
    await prefs.setString(_themesUpdatedKey, DateTime.now().toIso8601String());
  }

  static Future<List<Map<String, dynamic>>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_categoriesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<Map<String, dynamic>>> loadThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }
}
