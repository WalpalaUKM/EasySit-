import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class AuthPersistenceService {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/easysit_auth_prefs.json');
  }

  /// Sets the remember-me preference
  static Future<void> setRememberMe(bool rememberMe) async {
    try {
      final file = await _getFile();
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          data = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {}
      }
      data['rememberMe'] = rememberMe;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  /// Checks if remember-me is enabled
  static Future<bool> isRememberMe() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data['rememberMe'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Clears stored auth persistence preferences (e.g. on logout)
  static Future<void> clear() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
