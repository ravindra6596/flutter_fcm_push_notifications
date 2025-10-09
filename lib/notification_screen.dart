import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:push_notification/core/db_helper.dart';
import 'package:push_notification/di/configure.dart';
import 'package:push_notification/models/notifications.dart';
import 'package:push_notification/routing/app_router.dart';
import 'package:push_notification/utils/constants.dart';
import 'package:push_notification/utils/strings.dart';
/// notification list screen
@RoutePage()
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    notificationsFuture = fetchNotifications();
  }
  Future<void> refreshNotifications() async {
    setState(() {
      notificationsFuture = fetchNotifications();
    });

    int count = await DatabaseHelper().getNotificationCount();
    NotificationCountNotifier.updateCount(count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        actions: [
          ValueListenableBuilder<int>(
              valueListenable: NotificationCountNotifier.notifier,
              builder: (context, count, _) {
                return Visibility(
                  visible: count > 0,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      DatabaseHelper().deleteAllNotification();
                      setState(() {
                        notificationsFuture = fetchNotifications();
                      });
                      int count = await DatabaseHelper().getNotificationCount();
                      NotificationCountNotifier.notifier.value = count;
                    },
                    icon: Icon(Icons.delete),
                  ),
                );
              }),
        ],
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading notifications'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No notifications yet.'));
          }

          final notifications = snapshot.data!;
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notificationData = notifications[index];
              final isRead = notificationData.isReadNotification;
              var dateTime = DateTime.fromMillisecondsSinceEpoch(
                  int.parse(notificationData.receivedAt ?? ''));
              String receivedDateTime(int n) => n.toString().padLeft(2, '0');
              var h = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
              var local = dateTime.hour >= 12 ? 'PM' : 'AM';
              final displayTime =
                  formatTimeAgo(int.parse(notificationData.receivedAt ?? ''));
              return Padding(
                padding:  const EdgeInsets.symmetric(vertical: 3, horizontal: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                  child: ListTile(
                    dense: true,
                    onTap: () async {
                      if (notificationData.type != adminNotification) {
                        await DatabaseHelper().updateNotificationStatus(notificationData.notificationId.toString(), true);
                        getIt<AppRouter>().push(
                            DetailsRoute(notificationModel: notificationData));
                        refreshNotifications();
                      } else {}
                    },
                    visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                    tileColor: notificationData.type == adminNotification
                        ? Colors.green.shade100
                        : isRead ? Colors.grey.shade300 : Colors.grey.shade500,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                          color: Colors.black54),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    title: Text(
                      notificationData.title ?? ' ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          '${notificationData.body}',
                        ),
                        Text(
                          '${receivedDateTime(dateTime.day)}-${receivedDateTime(dateTime.month)}-${dateTime.year} ${receivedDateTime(h)}:${receivedDateTime(dateTime.minute)}:${receivedDateTime(dateTime.second)} $local',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                        Text(
                          notificationData.type?.toUpperCase() ?? '',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: notificationData.type == adminNotification
                                  ? Colors.grey
                                  : Colors.black),
                        ),
                      ],
                    ),
                    trailing: Container(
                      transform: Matrix4.translationValues(25, 0, 0),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          DatabaseHelper().deleteNotification(
                              notificationData.notificationId ?? '');
                          setState(() {
                            notificationsFuture = fetchNotifications();
                          });
                          int count =
                              await DatabaseHelper().getNotificationCount();
                          NotificationCountNotifier.notifier.value = count;
                        },
                        icon: Icon(Icons.clear),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
