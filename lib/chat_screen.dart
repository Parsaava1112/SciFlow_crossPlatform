import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shimmer/shimmer.dart';
import 'database_helper.dart';
import 'theme_provider.dart';
import 'particle_background.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final String username;
  const ChatScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _dbHelper = DatabaseHelper();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  DateTime? _thinkingStart;
  final List<String> _statusMessages = [
    'در حال جستجو...',
    'در حال فکر کردن...',
    'در حال نوشتن...',
    'کمی صبر کنید...',
    'در حال بررسی پایگاه داده...',
  ];
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = _statusMessages[Random().nextInt(_statusMessages.length)];
    _addMessage(ChatMessage(
        text: 'سلام ${widget.username}! چطور می‌تونم کمکت کنم؟',
        isUser: false));
  }

  void _addMessage(ChatMessage message) {
    setState(() => _messages.add(message));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _addMessage(ChatMessage(text: text, isUser: true));
    _messageController.clear();
    HapticFeedback.lightImpact(); // بازخورد لمسی

    setState(() {
      _isTyping = true;
      _thinkingStart = DateTime.now();
      _currentStatus = _statusMessages[Random().nextInt(_statusMessages.length)];
    });

    final questions = _splitQuestions(text);
    List<String> answers = [];
    for (var q in questions) {
      var result = await _processSingleQuestion(q);
      if (result != null) answers.add(result);
    }

    Duration thinkingDuration = DateTime.now().difference(_thinkingStart!);
    String timingInfo = '\n⏱️ مدت زمان: ${thinkingDuration.inMilliseconds / 1000} ثانیه';

    if (answers.isEmpty) {
      final newAnswer = await _showTeachDialog(text);
      if (newAnswer != null && newAnswer.isNotEmpty) {
        await _dbHelper.addQA(text, newAnswer);
        _addMessage(ChatMessage(text: newAnswer + timingInfo, isUser: false));
        _dbHelper.addChatHistory(widget.username, text, newAnswer);
      } else {
        _addMessage(ChatMessage(
            text: 'متأسفم، فعلاً پاسخی برای این سوال ندارم. 🤔' + timingInfo,
            isUser: false));
      }
    } else {
      String finalAnswer = answers.join('\n\n') + timingInfo;
      _addMessage(ChatMessage(text: finalAnswer, isUser: false));
      for (int i = 0; i < questions.length && i < answers.length; i++) {
        _dbHelper.addChatHistory(widget.username, questions[i], answers[i]);
      }
    }

    setState(() => _isTyping = false);
  }

  // متدهای کمکی (_splitQuestions, _processSingleQuestion, ...) عیناً مثل قبل
  // فقط در _buildMessageBubble تغییرات خواهیم داد

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      body: Stack(
        children: [
          ParticleBackground(
            speedMultiplier: _isTyping ? 2.5 : 1.0, // ذرات در حین تایپ سریعتر
          ),
          Column(
            children: [
              _buildAppBar(themeProvider),
              Expanded(
                child: _messages.isEmpty
                    ? const Center(child: Text('پیامی نداریم!'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isTyping) {
                            return _buildLoadingIndicator();
                          }
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
              ),
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[700]!,
      highlightColor: Colors.grey[500]!,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // آواتار بات
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.indigo.shade400,
              child: const FaIcon(FontAwesomeIcons.robot, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // حباب شیشه‌ای برای انیمیشن Lottie و وضعیت
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800.withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        topLeft: Radius.circular(4),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Lottie.asset('assets/animations/thinking.json'),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _currentStatus,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeProvider themeProvider) {
    return AppBar(
      title: Text('کاربر: ${widget.username}'),
      actions: [
        // انتخاب تم رنگی
        PopupMenuButton<AppTheme>(
          icon: const Icon(Icons.palette_outlined),
          onSelected: (theme) {
            themeProvider.setAppTheme(theme);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: AppTheme.defaultTheme, child: Text('پیش‌فرض')),
            const PopupMenuItem(value: AppTheme.nature, child: Text('طبیعت')),
            const PopupMenuItem(value: AppTheme.ocean, child: Text('اقیانوس')),
            const PopupMenuItem(value: AppTheme.golden, child: Text('طلایی')),
          ],
        ),
        // تغییر حالت تاریک/روشن
        IconButton(
          icon: Icon(themeProvider.themeMode == ThemeMode.dark
              ? Icons.light_mode
              : Icons.dark_mode),
          onPressed: () {
            themeProvider.setTheme(
              themeProvider.themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            );
          },
        ),
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.circleQuestion),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HelpScreen())),
        ),
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.clockRotateLeft),
          onPressed: () => _showHistory(),
        ),
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.gear),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.rightFromBracket),
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final borderRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut, // انیمیشن فنری
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.8 + (0.2 * value), // کمی بزرگ شدن
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.indigo.shade400,
                  child: const FaIcon(FontAwesomeIcons.robot, color: Colors.white, size: 20),
                ),
              ),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? Colors.green.shade700 : Colors.grey.shade800,
                  borderRadius: borderRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.text,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textDirection: TextDirection.rtl),
                    if (!isUser)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // لایک / دیسلایک (قبلی)
                            InkWell(
                              onTap: () => _rateAnswer(msg, true),
                              child: const Icon(Icons.thumb_up_alt_outlined,
                                  size: 18, color: Colors.greenAccent),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => _rateAnswer(msg, false),
                              child: const Icon(Icons.thumb_down_alt_outlined,
                                  size: 18, color: Colors.redAccent),
                            ),
                            const SizedBox(width: 12),
                            // دکمه کپی
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: msg.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('پاسخ کپی شد')),
                                );
                              },
                              child: const Icon(Icons.copy,
                                  size: 18, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (isUser)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.green,
                  child: const FaIcon(FontAwesomeIcons.user, size: 20, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // _rateAnswer مثل قبل

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).bottomAppBarTheme.color ?? const Color(0xFF1F2937),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'پیام خود را بنویسید...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                prefixIcon: const FaIcon(FontAwesomeIcons.pen, size: 16, color: Colors.white54),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF22C55E),
            child: IconButton(
              icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 18),
              onPressed: _sendMessage,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistory() async {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => HistoryScreen(username: widget.username)));
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}