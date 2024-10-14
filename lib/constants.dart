import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> loadEnv() async {
  await dotenv.load();
}

final String host = dotenv.env['BACKEND_SERVER'] ?? '';
final String apiKey = dotenv.env['TOGETHER_API_KEY'] ?? '';
