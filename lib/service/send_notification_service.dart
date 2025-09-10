import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:push_notification/server_key.dart';

/// send notification from frontend/ mobile device
class SendNotificationService {
  static void sendPushNotification(
    String token,
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    GetServerKey getServerKey = GetServerKey();
    String accessToken = await getServerKey.getServerKeyToken();
    log('Server Key - $accessToken');
    Map<String, String> header = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    Map<String, dynamic> jsonBody = {
      "message": {
        "token": token, // send it to specific user
        // "topic":"all", // send it to all user
        "notification": {
          "body": body,
          "title": title,
        },
        "data":data,
      }
    };
    // api call
    try {
      http.Response response = await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/fcm-push-notification-35e3d/messages:send'),
        headers: header,
        body: jsonEncode(jsonBody),
      );
      if (response.statusCode == 200) {
        log('Notification Sent Form mobile');
      } else {
        log('Notification Not Sent ${response.body}');
      }
    } catch (e) {
      log(e.toString());
    }
  }
}
