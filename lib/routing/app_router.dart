import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:push_notification/ui/notifications/details_screen.dart';
import 'package:push_notification/di/configure.dart';
import 'package:push_notification/ui/home/home_screen.dart';
import 'package:push_notification/models/notifications.dart';
import 'package:push_notification/ui/notifications/notification_screen.dart';
import 'package:push_notification/ui/splash/splash_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

// Service locator setup
  void setupLocator() {
    // Register your services and dependencies
    getIt.registerSingleton<AppRouter>(AppRouter());
  }

  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: SplashRoute.page, path: "/"),
        AutoRoute(page: HomeRoute.page),
        AutoRoute(page: NotificationRoute.page),
        AutoRoute(page: DetailsRoute.page),
      ];
}
