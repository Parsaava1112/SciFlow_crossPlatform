import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // آدرس بک‌اند خود را دقیقاً وارد کنید
  static const String baseUrl = 'https://sciflowa.runflare.run';

  /// بررسی سلامت سرور با استفاده از GET /
  static Future<bool> isServerOnline() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
      ).timeout(const Duration(seconds: 5));
      // هر پاسخی (200, 404, ...) یعنی سرور بالاست
      return true;
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

  /// ارسال سوال و پاسخ جدید برای یادگیری (به حالت تعلیق درمی‌آید)
  static Future<Map<String, dynamic>?> learnQuestion(String question, String answer) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/learn'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question, 'answer': answer}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // خطای 400 (تکراری، لینک دار و...) را برمی‌گردانیم
        final body = jsonDecode(response.body);
        return {'error': body['detail'] ?? 'خطا در ارسال'};
      }
    } catch (e) {
      return {'error': 'ارتباط با سرور برقرار نشد'};
    }
  }
}