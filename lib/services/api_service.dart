import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // آدرس بک‌اند را وارد کنید (در زمان توسعه می‌تواند 10.0.2.2 برای امولاتور باشد)
  static const String baseUrl = 'https://sciflowa.runflare.run'; // <-- IP سرور خود را بگذارید

  /// بررسی آنلاین بودن سرور با یک درخواست OPTIONS یا GET ساده
  static Future<bool> isServerOnline() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 404; // 404 هم یعنی سرور بالاست
    } catch (e) {
      return false;
    }
  }

  /// ارسال سوال و دریافت پاسخ
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
      return null;
    }
  }
}
