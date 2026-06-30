import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'theme_provider.dart';
import 'notifications.dart'; // فایلی که ساختیم

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // فعال‌سازی sqflite برای دسکتاپ
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // راه‌اندازی نوتیفیکیشن (فقط موبایل)
  if (Platform.isAndroid || Platform.isIOS) {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(); // برای iOS
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