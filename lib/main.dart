import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'login_screen.dart';
import 'theme_provider.dart';
import 'notifications.dart'; // فایل مشترک نوتیفیکیشن

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // فعال‌سازی sqflite برای ویندوز/لینوکس/مک
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // تلاش برای بارگذاری sqlite3.dll محلی (در ریشه پروژه)
    try {
      final dllPath = p.join(Directory.current.path, 'sqlite3.dll');
      if (File(dllPath).existsSync()) {
        // اگر کتابخانه sqlite3 مستقیم هم import شده باشد می‌توان از open استفاده کرد
        // ولی معمولاً با sqflite_common_ffi نیازی نیست؛ فقط فایل را در همان پوشه بگذارید
        print('✅ فایل sqlite3.dll در مسیر پروژه یافت شد.');
      } else {
        print('⚠️ فایل sqlite3.dll در ریشه پروژه پیدا نشد. ممکن است برنامه با خطا مواجه شود.');
      }
    } catch (e) {
      print('خطا در بارگذاری sqlite3.dll: $e');
    }
  }

  // راه‌اندازی نوتیفیکیشن (فقط روی موبایل)
  if (Platform.isAndroid || Platform.isIOS) {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const ScienceChatbotApp(),
    ),
  );
}

class ScienceChatbotApp extends StatelessWidget {
  const ScienceChatbotApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'چت‌بات علوم تجربی',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const LoginScreen(),
    );
  }
}