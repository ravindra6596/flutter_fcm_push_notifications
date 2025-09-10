import 'dart:developer';

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
      type TEXT
    )
    ''');
  }

  // insert notifications
  Future<int> insertNotifications(String notificationId, String title, String body,String type) async {
    final db = await dataBase;
    return await db.insert(
      notificationTable,
      {
        'notificationId': notificationId,
        'title': title,
        'body': body,
        'receivedAt': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': type,
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
}
