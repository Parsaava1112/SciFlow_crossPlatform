import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('راهنما'),
        backgroundColor: const Color(0xFF1F2937),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Text(
          '''# راهنمای کار با چت‌بات SciFlow

۱. معرفی
چت‌بات SciFlow برای پاسخ‌گویی به سوالات علوم تجربی طراحی شده است.

۲. نحوه استفاده
سوال خود را واضح بپرسید تا پاسخ مناسب دریافت کنید.

۳. نکات
- سوالات خود را کامل و شفاف بپرسید.
- از کلیدواژه‌های علمی استفاده کنید.
            ''',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}