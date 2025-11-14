import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:push_notification/core/db_helper.dart';
import 'package:push_notification/di/configure.dart';
import 'package:push_notification/routing/app_router.dart';
import 'package:push_notification/service/notification_service.dart';
import 'package:push_notification/utils/constants.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:push_notification/utils/locale_controller.dart';

/// background notification handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // NotificationService.notificationService.initialize();
  log('Background notification ID ${message.messageId}, Title ${message.notification?.title}, Body ${message.notification?.body}');
  await DatabaseHelper().insertNotifications(
      message.messageId ?? '',
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      message.data['type']
  );
}

final appLanguages = <String, String>{
  'english': 'en',
  'marathi': 'mr',
  'hindi': 'hi',
};
final appSupportedLocales = appLanguages.values
    .map((languageCode) => Locale.fromSubtags(languageCode: languageCode))
    .toList();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // await FirebaseMessaging.instance.getInitialMessage();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  NotificationService.notificationService.initialize();
  runApp(const MyApp());
  configureDependencies();
  AppRouter().setupLocator();
  await LocaleManager.loadLocale();// ✅ load saved language before runApp
  }

final appRouter = getIt<AppRouter>();
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    updateNotificationCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateNotificationCount();
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
        valueListenable: appLocale,
        builder: (context, locale, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Flutter FCM',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
            locale: locale,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: appSupportedLocales,
            // color: Theme.of(context).colorScheme.primaryContainer,
          routerConfig: appRouter.config()
        );
      }
    );
  }
}

