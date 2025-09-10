import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:push_notification/core/db_helper.dart';
import 'package:push_notification/di/configure.dart';
import 'package:push_notification/models/notifications.dart';
import 'package:push_notification/routing/app_router.dart';
import 'package:http/http.dart' as http;
import 'package:push_notification/utils/constants.dart';

/// manage notification routing / show / app open, close, kill, terminated, background
class NotificationService {
  static final NotificationService notificationService = NotificationService();
  final messaging = FirebaseMessaging.instance;
  final localNotification = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // request permission
    requestNotificationPermission();
    // setup notification message handler
    await backgroundMessage();
    getToken();
    initItNotificationInfo();
    sendAllUserNotification();
  }
  // send notification to all users
  void sendAllUserNotification(){
    messaging.subscribeToTopic('all');
  }
  // request permission
  Future<void> requestNotificationPermission() async {
    final setting = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
      announcement: true,
      carPlay: true,
      criticalAlert: true,
    );
    localNotification
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    if (setting.authorizationStatus == AuthorizationStatus.authorized) {
      log('Permission Status Allow - ${setting.authorizationStatus}');
    } else if (setting.authorizationStatus == AuthorizationStatus.provisional) {
      log('Permission Status Provisional');
    } else {
      log('Permission not granted or declined..');
    }
  }

  // get FCM token
  getToken() async {
    final token = await messaging.getToken();
    log('FCM Token $token');
  }

  // init firebase notification
  initItNotificationInfo() async {
    const initializedAndroidSetting = AndroidInitializationSettings('@mipmap/ic_launcher');
    // ios setup
    const initializedIOSDarwin = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: initializedAndroidSetting,
      iOS: initializedIOSDarwin,
    );
    // notification setup
    await localNotification.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        final data = jsonDecode(details.payload!);
        final remoteMessage = RemoteMessage(data: data);
        log('remoteMessage ${remoteMessage.data}');
        // handleRouting(remoteMessage);
        handleRouting(RemoteMessage(
          messageId: data['messageId'],
          data: data,
          notification: RemoteNotification(
            title: data['title'],
            body: data['body'],
          ),
        ));
      },
    );

    firebaseInitMessages();
  }

  firebaseInitMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      log(
          'Title - ${message.notification?.title}, Body - ${message.notification?.body} Type - ${message.data['type']}');

      if (Platform.isIOS) {
        iosForegroundMessage();
      } else {
        initItNotificationInfo();
        // handleRouting(message);
      }
      log('notification payload  : ${message.data}');
      log('notificationId ${message.messageId}');
      await DatabaseHelper().insertNotifications(
        message.messageId ?? '',
        message.notification?.title ?? '',
        message.notification?.body ?? '',
        message.data['type'] ?? ''
      );
      int count = await DatabaseHelper().getNotificationCount();
      NotificationCountNotifier.updateCount(count);
      log('Count $count');
      showNotification(message);
    });
  }

  // show notification
  Future<void> showNotification(RemoteMessage message) async {
    RemoteNotification? remoteNotification = message.notification;
    AndroidNotification? androidNotification = message.notification?.android;
    if (remoteNotification != null && androidNotification != null) {
      // for image inside notification
      final imageUrl = remoteNotification.android?.imageUrl ?? remoteNotification.apple?.imageUrl ?? message.notification?.title;
      BigPictureStyleInformation? bigPictureStyle;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final ByteArrayAndroidBitmap bigPicture = ByteArrayAndroidBitmap(
            await downloadAndConvertImage(imageUrl),
          );

          bigPictureStyle = BigPictureStyleInformation(
            bigPicture,
            contentTitle: remoteNotification.title,
            summaryText: remoteNotification.body,
          );
        } catch (e) {
          log('Failed to download image: $e');
        }
      }
      await localNotification.show(
        remoteNotification.hashCode,
        remoteNotification.title,
        remoteNotification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notification',
            channelDescription:
                'This channel is used for important notification',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableLights: true,
            channelShowBadge: true,
            icon: '@mipmap/ic_launcher',
            styleInformation: bigPictureStyle,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        // payload: jsonEncode(message.data),
        payload: jsonEncode({
          'messageId': message.messageId,
          'title': remoteNotification.title,
          'body': remoteNotification.body,
          ...message.data,  // spread other data fields here
        }),
      );
    }
  }

  Future iosForegroundMessage() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  backgroundMessage() async {
    // background
    FirebaseMessaging.onMessageOpenedApp.listen(
      (remoteMessage) {
        handleRouting(remoteMessage);
      },
    );
    // terminated
    FirebaseMessaging.instance.getInitialMessage().then(
      (remoteMessage) {
        if (remoteMessage != null && remoteMessage.data.isNotEmpty) {
          handleRouting(remoteMessage);
        }
      },
    );
  }
 // handle routing when receiving notification
  handleRouting(RemoteMessage message) {
    if (message.data['type'] == 'home') {
      getIt<AppRouter>().replace(HomeRoute());
      log('Redirection for message screen');
    }
    else if (message.data['type'] == 'notification') {
      log('Redirection for profile screen');
      getIt<AppRouter>().push(DetailsRoute(
        notificationModel: NotificationModel(
          title: message.notification?.title ?? '',
          body: message.notification?.body ?? '',
          notificationId: message.messageId ?? '',
          receivedAt: '1752838052570',
          type: message.data['type'],
        ),
      ));
    } else {
      log('Redirection for home screen');
    }
  }

  // function for display image inside notification
  Future<Uint8List> downloadAndConvertImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download image');
    }
  }
}
