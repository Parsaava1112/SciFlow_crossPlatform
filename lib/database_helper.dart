import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:string_similarity/string_similarity.dart';
import 'data.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'qa_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        username TEXT PRIMARY KEY,
        password_hash TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS qa (
        question TEXT PRIMARY KEY,
        answer TEXT,
        usage_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT,
        question TEXT,
        answer TEXT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS synonyms (
        word TEXT PRIMARY KEY,
        main_word TEXT
      )
    ''');

    // درج داده‌های اولیه
    await _insertInitialData(db);
  }

  Future<void> _insertInitialData(Database db) async {
    // درج QA
    for (var qa in initialQA) {
      await db.insert(
        'qa',
        {
          'question': qa['question'],
          'answer': qa['answer'],
          'usage_count': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // درج مترادف‌ها
    for (var syn in synonyms) {
      await db.insert(
        'synonyms',
        {
          'word': syn['word'],
          'main_word': syn['main_word'],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // در database_helper.dart، پس از smartSearch قبلی، این متدها را اضافه کنید:

  /// جستجوی هوشمند با برگرداندن درصد تطابق
  Future<Map<String, dynamic>?> smartSearchWithScore(String userQuestion) async {
    final db = await database;
    // جستجوی دقیق
    List<Map> exactMatch = await db.query('qa',
        where: 'LOWER(question) = LOWER(?)', whereArgs: [userQuestion]);
    if (exactMatch.isNotEmpty) {
      await _incrementUsage(db, exactMatch.first['question'] as String);
      return {'answer': exactMatch.first['answer'], 'score': 1.0};
    }
    // مترادف
    List<Map> syn = await db.query('synonyms',
        where: 'LOWER(word) = LOWER(?)', whereArgs: [userQuestion]);
    if (syn.isNotEmpty) {
      return await smartSearchWithScore(syn.first['main_word'] as String);
    }
    // جستجوی فازی
    final allQa = await db.query('qa');
    if (allQa.isEmpty) return null;
    final questions = allQa.map((e) => (e['question'] as String).toLowerCase()).toList();
    final bestMatch = userQuestion.toLowerCase().bestMatch(questions);
    if (bestMatch.bestMatch.rating != null && bestMatch.bestMatch.rating! >= 0.5) {
      final matchedQ = bestMatch.bestMatch.target!;
      final answer = allQa
          .firstWhere((e) => (e['question'] as String).toLowerCase() == matchedQ)['answer'] as String;
      await _incrementUsage(db, matchedQ);
      return {'answer': answer, 'score': bestMatch.bestMatch.rating};
    }
    return null;
  }

  /// ثبت امتیاز کاربر به یک پاسخ
  Future<void> rateAnswer(String username, String question, bool like) async {
    final db = await database;
    await db.execute('''CREATE TABLE IF NOT EXISTS ratings (
        username TEXT, question TEXT, rating INTEGER, 
        PRIMARY KEY(username, question)
    )''');
    await db.insert('ratings', {
      'username': username,
      'question': question,
      'rating': like ? 1 : -1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ثبت‌نام کاربر
  Future<Map<String, dynamic>> registerUser(String username, String password) async {
    if (password.length < 8) {
      return {'success': false, 'message': 'رمز عبور باید حداقل ۸ کاراکتر باشد'};
    }

    final db = await database;
    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

    try {
      await db.insert('users', {
        'username': username,
        'password_hash': passwordHash,
      });
      return {'success': true, 'message': 'ثبت نام موفق'};
    } catch (e) {
      return {'success': false, 'message': 'نام کاربری قبلاً ثبت شده است'};
    }
  }

  // احراز هویت
  Future<bool> authenticateUser(String username, String password) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (results.isNotEmpty) {
      final hash = results.first['password_hash'] as String;
      return BCrypt.checkpw(password, hash);
    }
    return false;
  }

  // جستجوی هوشمند
  Future<String?> smartSearch(String userQuestion) async {
    final db = await database;

    // جستجوی دقیق
    List<Map> exactMatch = await db.query(
      'qa',
      where: 'LOWER(question) = LOWER(?)',
      whereArgs: [userQuestion],
    );
    if (exactMatch.isNotEmpty) {
      await _incrementUsage(db, exactMatch.first['question'] as String);
      return exactMatch.first['answer'] as String;
    }

    // جستجوی مترادف
    List<Map> syn = await db.query(
      'synonyms',
      where: 'LOWER(word) = LOWER(?)',
      whereArgs: [userQuestion],
    );
    if (syn.isNotEmpty) {
      return await smartSearch(syn.first['main_word'] as String);
    }

    // جستجوی نزدیک‌ترین تطابق
    final allQa = await db.query('qa');
    if (allQa.isEmpty) return null;

    final questions = allQa.map((e) => (e['question'] as String).toLowerCase()).toList();
    final bestMatch = userQuestion.toLowerCase().bestMatch(questions);

    // اصلاح: اضافه کردن بررسی null و جایگزینی با مقدار پیش‌فرض
    if ((bestMatch.bestMatch.rating ?? 0) >= 0.6) {
      final matchedQuestion = bestMatch.bestMatch.target ?? '';
      final answer = allQa.firstWhere(
        (e) => (e['question'] as String).toLowerCase() == matchedQuestion
      )['answer'] as String;
      await _incrementUsage(db, matchedQuestion);
      return answer;
    }

    return null;
  }

  Future<void> _incrementUsage(Database db, String question) async {
    await db.rawUpdate(
      'UPDATE qa SET usage_count = usage_count + 1 WHERE question = ?',
      [question],
    );
  }

  // افزودن QA جدید
  Future<void> addQA(String question, String answer) async {
    final db = await database;
    await db.insert(
      'qa',
      {
        'question': question,
        'answer': answer,
        'usage_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ذخیره تاریخچه
  Future<void> addChatHistory(String username, String question, String answer) async {
    final db = await database;
    await db.insert('chat_history', {
      'username': username,
      'question': question,
      'answer': answer,
    });
  }

  // دریافت تاریخچه کاربر
  Future<List<Map<String, dynamic>>> getUserHistory(String username) async {
    final db = await database;
    return await db.query(
      'chat_history',
      where: 'username = ?',
      whereArgs: [username],
      orderBy: 'timestamp DESC',
      limit: 50,
    );
  }

  // سوالات پرتکرار
  Future<List<String>> getPopularQuestions(int limit) async {
    final db = await database;
    final results = await db.query(
      'qa',
      orderBy: 'usage_count DESC',
      limit: limit,
    );
    return results.map((e) => e['question'] as String).toList();
  }
}