import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'theme_provider.dart';

// تعریف سراسری برای استفاده در تنظیمات
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // فعال‌سازی sqflite برای دسکتاپ
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // راه‌اندازی نوتیفیکیشن (اندروید)
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // درخواست اجازه برای اندروید ۱۳+
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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
      theme: themeProvider.lightTheme,        // تم روشن دینامیک
      darkTheme: themeProvider.darkTheme,      // تم تاریک دینامیک
      themeMode: themeProvider.themeMode,      // حالت (روشن/تاریک/سیستم)
      home: const LoginScreen(),
    );
  }
}