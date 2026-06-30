import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

// این متغیر در main.dart تعریف شده
extern FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _weeklyReminder = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _weeklyReminder = prefs.getBool('weeklyReminder') ?? false;
    });
  }

  Future<void> _toggleReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      // زمان‌بندی هفتگی (مثلاً جمعه ساعت ۱۰ صبح)
      await flutterLocalNotificationsPlugin.periodicallyShow(
        0,
        'یادآور گفتگو',
        'سلام! وقت یک گپ دوستانه است. بیا سر بزن!',
        RepeatInterval.weekly,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_channel',
            'یادآور هفتگی',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } else {
      await flutterLocalNotificationsPlugin.cancel(0);
    }
    await prefs.setBool('weeklyReminder', value);
    setState(() => _weeklyReminder = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // تم رنگی
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('تم برنامه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Consumer<ThemeProvider>(
            builder: (_, themeProvider, __) {
              return ListTile(
                title: const Text('رنگ تم'),
                trailing: DropdownButton<AppTheme>(
                  value: themeProvider.appTheme,
                  onChanged: (val) {
                    if (val != null) themeProvider.setAppTheme(val);
                  },
                  items: const [
                    DropdownMenuItem(value: AppTheme.defaultTheme, child: Text('پیش‌فرض')),
                    DropdownMenuItem(value: AppTheme.nature, child: Text('طبیعت')),
                    DropdownMenuItem(value: AppTheme.ocean, child: Text('اقیانوس')),
                    DropdownMenuItem(value: AppTheme.golden, child: Text('طلایی')),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          // یادآور هفتگی
          SwitchListTile(
            title: const Text('یادآور هفتگی (جمعه‌ها)'),
            subtitle: const Text('هر هفته یک نوتیفیکیشن برای گپ زدن دریافت کن'),
            value: _weeklyReminder,
            onChanged: _toggleReminder,
          ),
        ],
      ),
    );
  }
}