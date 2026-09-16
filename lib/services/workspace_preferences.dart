import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WorkspacePreferences {
  static SharedPreferences? _prefs;
  static String? owner;
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Reset only navigation for a fresh login, preserving other preferences.
  static Future<void> resetForSignIn(String uid) async {
    if (_prefs == null) await initialize();
    owner = uid;
    final prefix = 'workspace_v1_${uid}_';
    await Future.wait([
      _prefs!.remove('${prefix}selection_admin_panel'),
      for (final role in ['admin', 'teacher', 'trainer', 'student']) ...[
        _prefs!.remove('${prefix}${role}_tab'),
        _prefs!.remove('${prefix}${role}_pages'),
      ],
    ]);
  }

  static String? selection(String key) =>
      _prefs?.getString('workspace_v1_${owner}_selection_$key');
  static Future<void> saveSelection(String key, String value) async {
    if (owner != null)
      await _prefs?.setString('workspace_v1_${owner}_selection_$key', value);
  }

  static int tab(String role, int count) {
    final value = _prefs?.getInt('workspace_v1_${owner}_${role}_tab') ?? 0;
    return value >= 0 && value < count ? value : 0;
  }

  static Future<void> saveTab(String role, int index) async {
    if (owner != null)
      await _prefs?.setInt('workspace_v1_${owner}_${role}_tab', index);
  }

  static List<Map<String, dynamic>> pages(String role) {
    try {
      final data = jsonDecode(
        _prefs?.getString('workspace_v1_${owner}_${role}_pages') ?? '[]',
      );
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v))
          .take(12)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePages(
    String role,
    List<Map<String, dynamic>> pages,
  ) async {
    if (owner != null)
      await _prefs?.setString(
        'workspace_v1_${owner}_${role}_pages',
        jsonEncode(pages.take(12).toList()),
      );
  }
}
