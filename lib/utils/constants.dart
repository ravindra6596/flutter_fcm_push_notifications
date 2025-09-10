import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:push_notification/core/db_helper.dart';
import 'package:push_notification/models/notifications.dart';

class NotificationCountNotifier {
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void updateCount(int newCount) {
    notifier.value = newCount;
  }
}

String formatTimeAgo(int timestampMillis) {
  final now = DateTime.now();
  final time = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
  final difference = now.difference(time);

  if (difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hr ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
  } else {
    // Return date like "Jul 15, 2025"
    return '${time.day} ${_monthName(time.month)}, ${time.year}';
  }
}

String _monthName(int month) {
  const months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return months[month];
}

late Future<List<NotificationModel>> notificationsFuture;

// fetch notifications
Future<List<NotificationModel>> fetchNotifications() async {
  final dbHelper = DatabaseHelper();
  final rawList = await dbHelper.getAllNotifications();
  return rawList.map((e) => NotificationModel.fromMap(e)).toList();
}

// update notification count
void updateNotificationCount() async {
  int count = await DatabaseHelper().getNotificationCount();
  NotificationCountNotifier.updateCount(count);
}
