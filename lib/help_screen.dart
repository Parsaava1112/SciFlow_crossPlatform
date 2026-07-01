import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('راهنما'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // سربرگ
              const Text(
                'راهنمای SciFlow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'هر آنچه برای استفاده از چت‌بات نیاز دارید',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              // بخش معرفی
              _buildInfoCard(),
              const SizedBox(height: 16),
              // بخش نحوه استفاده
              _buildUsageCard(),
              const SizedBox(height: 16),
              // بخش نکات
              _buildTipsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return _buildCard(
      icon: Icons.info_outline,
      title: 'معرفی',
      child: const Text(
        'چت‌بات SciFlow برای پاسخ‌گویی به سوالات علوم تجربی طراحی شده است. این دستیار هوشمند می‌تواند به شما در یادگیری مفاهیم علمی کمک کند.',
        style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildUsageCard() {
    return _buildCard(
      icon: Icons.help_outline,
      title: 'نحوه استفاده',
      child: const Text(
        'سوال خود را به صورت واضح و کامل در کادر چت بنویسید تا پاسخ مناسب و دقیقی دریافت کنید. سعی کنید زمینه سوال خود را مشخص کنید.',
        style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildTipsCard() {
    return _buildCard(
      icon: Icons.lightbulb_outline,
      title: 'نکات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTipItem('سوالات خود را کامل و شفاف بپرسید.'),
          const SizedBox(height: 8),
          _buildTipItem('از کلیدواژه‌های علمی مرتبط استفاده کنید.'),
          const SizedBox(height: 8),
          _buildTipItem('در صورت نیاز، زمینه سوال را توضیح دهید.'),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    const Color accent = Color(0xFF38BDF8); // آبی روشن
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          right: BorderSide(color: accent, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    const Color accent = Color(0xFF38BDF8);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}