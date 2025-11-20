import 'dart:developer';

import 'package:auto_route/annotations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:push_notification/core/db_helper.dart';
import 'package:push_notification/di/configure.dart';
import 'package:push_notification/routing/app_router.dart';
import 'package:push_notification/service/notification_service.dart';
import 'package:push_notification/service/send_notification_service.dart';
import 'package:push_notification/ui/QS/feedback_form.dart';
import 'package:push_notification/ui/QS/new_getx_feedback.dart';
import 'package:push_notification/ui/QS/privacy_policy.dart';
import 'package:push_notification/ui/fav.dart';
import 'package:push_notification/ui/lang.dart';
import 'package:push_notification/ui/speech_text.dart';
import 'package:push_notification/utils/constants.dart';
import 'package:push_notification/utils/strings.dart';
import 'package:share_plus/share_plus.dart';

// home screen or send notification from mobile
@RoutePage()
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final messaging = FirebaseMessaging.instance;
  var userNameController = TextEditingController();
  var titleController = TextEditingController();
  var bodyController = TextEditingController();
  final localNotification = FlutterLocalNotificationsPlugin();
  final globalKey = GlobalKey<FormState>();
  late Future<int> notificationCountFuture;

  @override
  void initState() {
    super.initState();
    notificationCountFuture = DatabaseHelper().getNotificationCount();
    updateNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FCM'),
        actions: [
          ValueListenableBuilder<int>(
              valueListenable: NotificationCountNotifier.notifier,
              builder: (context, notificationCount, _) {
              return  Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications),
                    onPressed: () =>
                        getIt<AppRouter>().push(NotificationRoute()),
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            notificationCount > 9 ? '9+' : '$notificationCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(10),
        child: Form(
          key: globalKey,
          child: Column(
            spacing: 10,
            children: [
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: title,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter title text';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: bodyController,
                decoration: InputDecoration(
                  hintText: body,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter body text';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  // DocumentSnapshot docSnap = await FirebaseFirestore.instance.collection('userToken').doc(userNameController.text.trim()).get();
                  if (globalKey.currentState!.validate()) {
                    final token = await messaging.getToken();

                    log('accessToken : $token');
                    // below function call for send notification when button click
                    SendNotificationService.sendPushNotification(
                      token!,
                      titleController.text,
                      bodyController.text,
                      {'type': 'home'},
                    );
                  }
                },
                child: Text('Submit'),
              ),

              ElevatedButton(
                onPressed: () async {
                  // Create a mock RemoteMessage object
                  RemoteMessage mockMessage = RemoteMessage(
                    notification: RemoteNotification(
                      title: 'Transaction Complete',
                      body: 'Your transaction was successfully completed!',
                      android: AndroidNotification(
                        imageUrl: 'https://images.pexels.com/photos/1172064/pexels-photo-1172064.jpeg', // Add image URL if needed
                      ),
                    ),
                    data: {
                      'transactionId': '12345',
                      'status': 'completed',
                    },
                  );

                  // Call showNotification with the mock message
                  NotificationService().showNotification(mockMessage);
                },
                child: Text('Local Notification'),
              ),

              ElevatedButton(
                onPressed: () async {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => BeautifulFeedbackForm(),));
                },
                child: Text('FeedBack'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => FeedbackFormGetX(),));
                },
                child: Text('GetX FeedBack'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyPolicy(),));
                },
                child: Text('Privacy Policy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LanguageApp(),));
                },
                child: Text('Language'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => SpeechSampleApp(),));
                },
                child: Text('SpeechSampleApp'),
              ),
              ElevatedButton(
                onPressed: () async {
                  const String appPackageName = 'com.unicornwings.quiz_sprint'; // replace with your actual package name
                  final String playStoreLink = 'https://play.google.com/store/apps/details?id=$appPackageName';

                  SharePlus.instance.share(
                      ShareParams(
                        title: 'Ace Your Exams with QuizSprint — Study Smarter, Not Harder! 🎯',
                        subject: 'Boost Your Exam Prep with QuizSprint! 📚',
                        text: 'Get ready to conquer your exams with QuizSprint — the ultimate interactive learning app!\n\n'
                            'Practice MCQs, track your progress, and master every topic with personalized quizzes and detailed explanations.\n\n'
                            '📚 Download now and unlock your full potential:\n$playStoreLink',
                        excludedCupertinoActivities: [CupertinoActivityType.airDrop],
                      ),
                  );
                  },
                child: Text('Share App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
