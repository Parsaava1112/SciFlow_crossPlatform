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
    HapticFeedback.lightImpact();

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

  // ---------- متدهای کمکی ----------
  List<String> _splitQuestions(String text) {
    final separators = [' و ', '،', ' همچنین ', ' و همچنین '];
    for (var sep in separators) {
      if (text.contains(sep)) {
        return text.split(sep).where((s) => s.trim().isNotEmpty).toList();
      }
    }
    return [text];
  }

  Future<String?> _processSingleQuestion(String question) async {
    if (_isGreeting(question)) {
      final baseAnswer = await _dbHelper.smartSearch(question);
      if (baseAnswer != null) {
        final now = Jalali.now();
        final dateStr = '${now.day} ${now.formatter.mN} ${now.year}';
        return '$baseAnswer\nامروز $dateStr است.';
      }
      return null;
    }

    String? unitResult = _tryConvertUnit(question);
    if (unitResult != null) return unitResult;

    String? mathResult = _tryEvaluateMath(question);
    if (mathResult != null) return mathResult;

    final result = await _dbHelper.smartSearchWithScore(question);
    if (result != null) {
      String answer = result['answer'];
      double score = result['score'];
      String percentage = (score * 100).toStringAsFixed(1);
      answer += '\n(میزان تطابق: $percentage٪)';
      return answer;
    }
    return null;
  }

  bool _isGreeting(String text) {
    final greetings = ['سلام', 'درود', 'سلام علیکم', 'خوبی', 'چطوری', 'سلامت'];
    return greetings.any((g) => text.contains(g));
  }

  String? _tryConvertUnit(String input) {
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*(\S+)\s+به\s+(\S+)');
    final match = regex.firstMatch(input);
    if (match == null) return null;

    double value = double.tryParse(match.group(1)!) ?? 0;
    String from = match.group(2)!.toLowerCase().replaceAll('?', '');
    String to = match.group(3)!.toLowerCase().replaceAll('?', '');

    const unitMap = {
      'کیلومتر': 'km', 'متر': 'm', 'سانتی‌متر': 'cm', 'مایل': 'mile',
      'کیلوگرم': 'kg', 'گرم': 'g', 'پوند': 'lb',
      'سانتی‌گراد': 'celsius', 'فارنهایت': 'fahrenheit',
      'درجه سانتی‌گراد': 'celsius', 'درجه فارنهایت': 'fahrenheit',
    };

    String? fromUnit = unitMap[from];
    String? toUnit = unitMap[to];
    if (fromUnit == null || toUnit == null) return null;

    try {
      double result = _convertUnitManually(value, fromUnit, toUnit);
      if (result.isNaN) return null;
      return '$value $from = ${result.toStringAsFixed(2)} $to';
    } catch (_) {
      return null;
    }
  }

  double _convertUnitManually(double value, String from, String to) {
    if (from == 'celsius' && to == 'fahrenheit') return value * 9 / 5 + 32;
    if (from == 'fahrenheit' && to == 'celsius') return (value - 32) * 5 / 9;

    const toBase = {
      'km': 1000.0, 'm': 1.0, 'cm': 0.01, 'mile': 1609.34,
      'kg': 1.0, 'g': 0.001, 'lb': 0.453592,
    };
    const fromBase = {
      'km': 1 / 1000.0, 'm': 1.0, 'cm': 100.0, 'mile': 1 / 1609.34,
      'kg': 1.0, 'g': 1000.0, 'lb': 1 / 0.453592,
    };

    double inBase = value * (toBase[from] ?? 1.0);
    return inBase * (fromBase[to] ?? 1.0);
  }

  String? _tryEvaluateMath(String input) {
    final mathRegex = RegExp(r'^[\d+\-*/().\s]+$');
    if (!mathRegex.hasMatch(input)) return null;
    try {
      final exp = Parser().parse(input);
      final result = exp.evaluate(EvaluationType.REAL, ContextModel());
      return '$input = $result';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _showTeachDialog(String question) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('یادگیری'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('من جواب این سوال را نمی‌دانم:\n"$question"\nلطفاً پاسخ صحیح را وارد کنید:'),
            const SizedBox(height: 12),
            TextField(controller: controller,
                decoration: const InputDecoration(hintText: 'پاسخ...', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('ذخیره')),
        ],
      ),
    );
  }

  void _rateAnswer(ChatMessage msg, bool like) async {
    String? lastQuestion;
    for (int i = _messages.indexOf(msg) - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        lastQuestion = _messages[i].text;
        break;
      }
    }
    if (lastQuestion != null) {
      await _dbHelper.rateAnswer(widget.username, lastQuestion, like);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(like ? '👍 متشکرم!' : '👎 ثبت شد.')),
      );
    }
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      body: Stack(
        children: [
          ParticleBackground(
            speedMultiplier: _isTyping ? 2.5 : 1.0,
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
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.indigo.shade400,
              child: const FaIcon(FontAwesomeIcons.robot, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
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
        PopupMenuButton<AppTheme>(
          icon: const Icon(Icons.palette_outlined),
          onSelected: (theme) {
            themeProvider.setAppTheme(theme);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: AppTheme.defaultTheme, child: Text('پیش‌فرض')),
            PopupMenuItem(value: AppTheme.nature, child: Text('طبیعت')),
            PopupMenuItem(value: AppTheme.ocean, child: Text('اقیانوس')),
            PopupMenuItem(value: AppTheme.golden, child: Text('طلایی')),
          ],
        ),
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
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.8 + (0.2 * value),
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