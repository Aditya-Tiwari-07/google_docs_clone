import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String? _host;
  static String? _apiKey;

  static Future<void> load() async {
    await dotenv.load();
    _host = dotenv.env['BACKEND_SERVER'];
    _apiKey = dotenv.env['TOGETHER_API_KEY'];
  }

  static String get host => _host ?? '';
  static String get apiKey => _apiKey ?? '';
}
