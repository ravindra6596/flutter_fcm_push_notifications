// ignore_for_file: must_be_immutable
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:push_notification/models/notifications.dart';

// notification details screen
@RoutePage()
class DetailsScreen extends StatelessWidget {
   DetailsScreen({super.key,this.notificationModel});
  NotificationModel? notificationModel = NotificationModel();

  @override
  Widget build(BuildContext context) {
    var dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(notificationModel?.receivedAt ?? ''));
    String receivedDateTime(int n) => n.toString().padLeft(2, '0');
    var h = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    var local = dateTime.hour >= 12 ? 'PM' : 'AM';
    return Scaffold(
      appBar: AppBar(
        title: Text('Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notification ID:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(notificationModel?.notificationId ?? ''),
            SizedBox(height: 16),

            Text('Title:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(notificationModel?.title ?? ''),
            SizedBox(height: 16),

            Text('Body:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(notificationModel?.body ?? ''),
            SizedBox(height: 16),

            Text('Received At:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('${receivedDateTime(dateTime.day)}-${receivedDateTime(dateTime.month)}-${dateTime.year} ${receivedDateTime(h)}:${receivedDateTime(dateTime.minute)}:${receivedDateTime(dateTime.second)} $local',
            ),
          ],
        ),
      ),
    );
  }
}
