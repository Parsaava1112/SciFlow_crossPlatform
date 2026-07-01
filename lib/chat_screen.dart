import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
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
  bool _showScrollButton = false;
  final List<String> _statusMessages = [
    'در حال جستجو...',
    'در حال فکر کردن...',
    'در حال نوشتن...',
    'کمی صبر کنید...',
    'در حال بررسی پایگاه داده...',
  ];
  late String _currentStatus;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _currentStatus = _statusMessages[Random().nextInt(_statusMessages.length)];
    _addMessage(ChatMessage(
        text: 'سلام ${widget.username}! چطور می‌تونم کمکت کنم؟',
        isUser: false));

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final offset = _scrollController.offset;
        if (maxScroll - offset > 100 && !_showScrollButton) {
          setState(() => _showScrollButton = true);
        } else if (maxScroll - offset <= 100 && _showScrollButton) {
          setState(() => _showScrollButton = false);
        }
      }
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
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

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays} روز پیش';
    if (diff.inHours > 0) return '${diff.inHours} ساعت پیش';
    if (diff.inMinutes > 0) return '${diff.inMinutes} دقیقه پیش';
    return 'همین الان';
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
      _currentStatus =
          _statusMessages[Random().nextInt(_statusMessages.length)];
      _bounceController.repeat(reverse: true);
    });

    final questions = _splitQuestions(text);
    List<String> answers = [];
    for (var q in questions) {
      var result = await _processSingleQuestion(q);
      if (result != null) answers.add(result);
    }

    Duration thinkingDuration = DateTime.now().difference(_thinkingStart!);
    String timingInfo =
        '\n⏱️ مدت زمان: ${(thinkingDuration.inMilliseconds / 1000).toStringAsFixed(2)} ثانیه';

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

    setState(() {
      _isTyping = false;
      _bounceController.stop();
      _bounceController.reset();
    });
  }

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
    final greetings = [
      'سلام',
      'درود',
      'سلام علیکم',
      'خوبی',
      'چطوری',
      'سلامت'
    ];
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
      'کیلومتر': 'km',
      'متر': 'm',
      'سانتی‌متر': 'cm',
      'مایل': 'mile',
      'کیلوگرم': 'kg',
      'گرم': 'g',
      'پوند': 'lb',
      'سانتی‌گراد': 'celsius',
      'فارنهایت': 'fahrenheit',
      'درجه سانتی‌گراد': 'celsius',
      'درجه فارنهایت': 'fahrenheit',
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
      'km': 1000.0,
      'm': 1.0,
      'cm': 0.01,
      'mile': 1609.34,
      'kg': 1.0,
      'g': 0.001,
      'lb': 0.453592,
    };
    const fromBase = {
      'km': 1 / 1000.0,
      'm': 1.0,
      'cm': 100.0,
      'mile': 1 / 1609.34,
      'kg': 1.0,
      'g': 1000.0,
      'lb': 1 / 0.453592,
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
            Text(
                'من جواب این سوال را نمی‌دانم:\n"$question"\nلطفاً پاسخ صحیح را وارد کنید:'),
            const SizedBox(height: 12),
            TextField(
                controller: controller,
                decoration: const InputDecoration(
                    hintText: 'پاسخ...', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(like ? '👍 متشکرم!' : '👎 ثبت شد.')),
      );
    }
  }

  void _showEmojiReaction(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('واکنش خود را انتخاب کنید',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['👍', '❤️', '😂', '😮', '😢', '🔥', '👎', '✨']
                    .map((emoji) => GestureDetector(
                          onTap: () {
                            setState(() => msg.reaction = emoji);
                            Navigator.pop(ctx);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 32)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          ParticleBackground(
            theme: themeProvider.appTheme, // اصلاح‌شده: appTheme به‌جای currentAppTheme
            speedMultiplier: _isTyping ? 2.5 : 1.0,
          ),
          Column(
            children: [
              _buildAppBar(themeProvider),
              Expanded(
                child: _messages.isEmpty
                    ? _buildWelcomeScreen(themeProvider, isDark)
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount:
                                _messages.length + (_isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _messages.length && _isTyping) {
                                return _buildLoadingIndicator(isDark);
                              }
                              return _buildMessageBubble(
                                  _messages[index], isDark, themeProvider);
                            },
                          ),
                          if (_showScrollButton)
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: AnimatedScale(
                                  scale: _showScrollButton ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: FloatingActionButton(
                                    mini: true,
                                    backgroundColor: Colors.indigoAccent,
                                    onPressed: () {
                                      _scrollController.animateTo(
                                        _scrollController
                                            .position.maxScrollExtent,
                                        duration:
                                            const Duration(milliseconds: 500),
                                        curve: Curves.easeOutBack,
                                      );
                                    },
                                    child: const Icon(
                                        Icons.keyboard_double_arrow_down_rounded,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              _buildInputArea(bottomPadding),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen(ThemeProvider themeProvider, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/welcome.json',
              height: 200,
              errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.chat_bubble_outline,
                  size: 120,
                  color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color:
                        (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'سلام ${widget.username}! 👋',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'چطور می‌تونم کمکت کنم؟',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'یه جوک بگو',
                          'آب و هوا',
                          'تبدیل واحد',
                          'محاسبه ریاضی',
                          'امروز چه روزیه؟'
                        ].map((item) {
                          return ActionChip(
                            avatar: const Icon(Icons.touch_app, size: 16),
                            label: Text(item),
                            backgroundColor: Colors.white.withOpacity(0.2),
                            onPressed: () {
                              _messageController.text = item;
                              _sendMessage();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[700]!,
      highlightColor: Colors.grey[500]!,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -_bounceAnimation.value),
                child: child,
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.indigo.shade400,
                child: const FaIcon(FontAwesomeIcons.robot,
                    color: Colors.white, size: 20),
              ),
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
                    _buildLottieOrFallback(),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _currentStatus,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
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

  Widget _buildLottieOrFallback() {
    try {
      return Lottie.asset(
        'assets/animations/thinking.json',
        width: 40,
        height: 40,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          );
        },
      );
    } catch (e) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
        ),
      );
    }
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
            PopupMenuItem(
                value: AppTheme.defaultTheme, child: Text('پیش‌فرض')),
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

  Widget _buildMessageBubble(
      ChatMessage msg, bool isDark, ThemeProvider themeProvider) {
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

    BoxDecoration decoration;
    if (isDark) {
      decoration = BoxDecoration(
        color: (isUser ? Colors.green : Colors.indigo).withOpacity(0.15),
        borderRadius: borderRadius,
        border:
            Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      );
    } else {
      decoration = BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade400,
              offset: const Offset(4, 4),
              blurRadius: 8,
              spreadRadius: 1),
          const BoxShadow(
              color: Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 8,
              spreadRadius: 1),
        ],
      );
    }

    Widget bubbleContent = Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: decoration,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.text,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 4),
              Text(
                _timeAgo(msg.timestamp),
                style: TextStyle(
                  color:
                      (isDark ? Colors.white : Colors.black45).withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _rateAnswer(msg, true),
                        child: Icon(Icons.thumb_up_alt_outlined,
                            size: 18,
                            color: isDark
                                ? Colors.greenAccent
                                : Colors.green),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => _rateAnswer(msg, false),
                        child: Icon(Icons.thumb_down_alt_outlined,
                            size: 18,
                            color:
                                isDark ? Colors.redAccent : Colors.red),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: msg.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('پاسخ کپی شد')),
                          );
                        },
                        child: Icon(Icons.copy,
                            size: 18,
                            color: isDark
                                ? Colors.white54
                                : Colors.black45),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (msg.reaction != null)
            Positioned(
              left: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2), blurRadius: 4)
                  ],
                ),
                child: Text(msg.reaction!,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );

    if (isDark) {
      bubbleContent = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: bubbleContent,
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        final safeOpacity = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: safeOpacity,
          child: Transform.scale(
              scale: 0.8 + (0.2 * safeOpacity), child: child),
        );
      },
      child: GestureDetector(
        onLongPress: () => _showEmojiReaction(msg),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment:
                isUser ? Alignment.centerRight : Alignment.centerLeft,
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
                      child: const FaIcon(FontAwesomeIcons.robot,
                          color: Colors.white, size: 20),
                    ),
                  ),
                Flexible(child: bubbleContent),
                if (isUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.green,
                      child: const FaIcon(FontAwesomeIcons.user,
                          size: 20, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).bottomAppBarTheme.color ??
            const Color(0xFF1F2937),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                prefixIcon: const FaIcon(FontAwesomeIcons.pen,
                    size: 16, color: Colors.white54),
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
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => HistoryScreen(username: widget.username)));
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  String? reaction;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.reaction,
  }) : timestamp = timestamp ?? DateTime.now();
}