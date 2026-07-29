import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // این آدرس را به IP و پورت سرور خود تغییر دهید
  static const String baseUrl = 'http://192.168.1.100:8000';

  /// سوال را به بک‌اند می‌فرستد و پاسخ را برمی‌گرداند.
  /// در صورت قطعی اینترنت یا خطای سرور، null برمی‌گرداند.
  static Future<Map<String, dynamic>?> askQuestion(String question) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      // هر نوع خطا (شبکه، timeout و...)
      return null;
    }
  }
}