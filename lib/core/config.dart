import 'package:shared_preferences/shared_preferences.dart';

/// Which TeamSavy server the app talks to. Defaults to production; a dev
/// build can point elsewhere with
/// `--dart-define=API_BASE_URL=http://10.0.2.2:3000`, and the server can
/// also be changed at runtime from the sign-in screen (long-press the logo),
/// which is remembered on the device.
class AppConfig {
  static const defaultBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://app.teamsavy.com');

  static String baseUrl = defaultBaseUrl;

  static const _key = 'api_base_url';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) baseUrl = saved;
  }

  static Future<void> setBaseUrl(String url) async {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.isEmpty) clean = defaultBaseUrl;
    baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, clean);
  }
}
