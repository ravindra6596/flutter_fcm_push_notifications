import 'dart:developer';

import 'package:push_notification/ui/lang.dart';
import 'package:push_notification/utils/strings.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// manage notifications show the device
class DatabaseHelper {
  static Database? databaseData;

// database creation
  Future<Database> get dataBase async {
    try {
      if (databaseData != null) {
        return databaseData!;
      } else {
        databaseData = await initDataBase();
        if (databaseData != null) {
          log('Database is not null');
        }
      }
    } catch (e) {
      log('error while getting database $databaseData');
      databaseData = await initDataBase();
    }
    return databaseData!;
  }

// database initialization
  Future<Database> initDataBase() async {
    String databasePath = join(await getDatabasesPath(), '$appName.db');
    return await openDatabase(
      databasePath,
      version: 1,
      onCreate: onCreateDatabase,
    );
  }

  /// Defines the schema of the notifications table.
  Future<void> onCreateDatabase(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $notificationTable (
      notificationId TEXT PRIMARY KEY ,
      title TEXT,
      body TEXT,
      receivedAt TEXT,
      type TEXT,
      isReadNotification INTEGER
    )
    ''');
    await db.execute('''
        CREATE TABLE fav_slokas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          chapter INTEGER,
          verse INTEGER,
          chapterName TEXT,
          text TEXT,
          meaning TEXT,
          explanation TEXT,
          isFavourite INTEGER,
          language TEXT
        )
      ''');
    await db.execute('''
        CREATE TABLE sloka_read_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        chapterName TEXT NOT NULL,
        language TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        UNIQUE(chapter, verse, language)

       )
      ''');
  }

  // insert notifications
  Future<int?> insertNotifications(String notificationId, String title, String body,String type) async {
    // Check if required fields are not null or empty
    if (notificationId.isEmpty || title.isEmpty || body.isEmpty || type.isEmpty) {
      log('Skipped inserting invalid notification');
      return null;
    }
    final db = await dataBase;
    return await db.insert(
      notificationTable,
      {
        'notificationId': notificationId,
        'title': title,
        'body': body,
        'receivedAt': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': type,
        'isReadNotification': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// get all notification lists
  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    final db = await dataBase;
    return await db.query(
      notificationTable,
      orderBy: 'receivedAt DESC',
    );
  }

  /// get notification count
  Future<int> getNotificationCount() async {
    final db = await dataBase;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $notificationTable'),
      // if need to display unread notification count from list then use below line
      // await db.rawQuery('SELECT COUNT(*) FROM $notificationTable WHERE isReadNotification = 0'),
    ) ?? 0;
  }

  /// delete selected notification by id
  Future<int> deleteNotification(String notificationId) async {
    final db = await dataBase;
    int count = await db.delete(
      notificationTable,
      where: 'notificationId = ?',
      whereArgs: [notificationId],
    );
    log('Deleted rows count: $count');
    return count;
  }
  /// delete / clear all notifications
  Future<int> deleteAllNotification() async {
    final db = await dataBase;
    int count = await db.delete(
      notificationTable,
    );
    return count;
  }
  // update listing bookmark
  Future<void> updateNotificationStatus(String id,  bool readNotification) async {
    log('Notification method call');
    final db = await dataBase;
    int isReadNotification = readNotification ? 1 : 0;
    final existingSection = await db.query(
      notificationTable,
      where: 'notificationId = ?',
      whereArgs: [id],
    );

    if (existingSection.isNotEmpty) {
      await db.update(
        notificationTable,
        {
          'isReadNotification': isReadNotification,
        },
        where: 'notificationId = ?',
        whereArgs: [id],
      );
      log('Notification read/open with $id');
    } else {
      log('Notification Already read Id - $id');
    }
  }

  Future<int> addFav(  Sloka sloka, String language,String chapterName) async {
    final database = await dataBase;
    return await database.insert('fav_slokas', {
      'chapter': sloka.chapter,
      'verse': sloka.verse,
      'text': sloka.text,
      'meaning': sloka.meaning,
      'explanation': sloka.explanation,
      'chapterName': chapterName,
      'isFavourite': sloka.explanation,
      'language': language,
    });
  }

  Future<int> removeFav({required int chapter, required int verse, required String language}) async {
    final database = await dataBase;
    return await database.delete(
      'fav_slokas',
      where: 'chapter = ? AND verse = ? AND language = ?',
      whereArgs: [chapter, verse, language],
    );
  }

  Future<List<Map<String, dynamic>>> getFavs({String? language}) async {
    final database = await dataBase;
    if (language != null) {
      return await database.query('fav_slokas', where: 'language = ?', whereArgs: [language]);
    }
    return await database.query('fav_slokas');
  }

  Future<bool> isFav({required int chapter, required int verse, required String language}) async {
    final database = await dataBase;
    final result = await database.query(
      'fav_slokas',
      where: 'chapter = ? AND verse = ? AND language = ?',
      whereArgs: [chapter, verse, language],
    );
    return result.isNotEmpty;
  }

   markSlokaRead(
      int chapter,
      int verse,
      String chapterName,
      String language,
   ) async {
    final db = await dataBase;
    await db.insert(
      'sloka_read_status',
      {
        'chapter': chapter,
        'verse': verse,
        'chapterName': chapterName,
        'language': language,
        'isRead': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,  // or .ignore + update
    );
  }

  Future<int> getReadCount( String language, int chapter) async {
    final db = await dataBase;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sloka_read_status WHERE language = ? AND chapter = ? AND isRead = 1',
        [language,chapter]
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<int>> getReadSlokaVerses(String language, int chapter) async {
    final db = await dataBase;
    final result = await db.rawQuery(
      'SELECT verse FROM sloka_read_status WHERE language = ? AND chapter = ? AND isRead = 1',
      [language, chapter],
    );
    return result.map((row) => row['verse'] as int).toList();
  }


  Future<int> getTotalSlokasCount({required int chapter, required String language}) async {
    // If you have a table/list of all slokas you can query count from there
    final db = await dataBase;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM slokas WHERE chapter = ? AND language = ?',
        [chapter, language]
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
  Future<void> clearTable(String tableName) async {
    final db = await dataBase;
    await db.delete(tableName);
  }
}
