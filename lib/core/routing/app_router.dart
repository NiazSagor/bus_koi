import 'package:flutter/material.dart';

import 'package:bus_koi/features/community/presentation/community_screen.dart';
import 'package:bus_koi/features/home/presentation/home_screen.dart';
import 'package:bus_koi/features/settings/presentation/settings_screen.dart';

class AppRouter {
  AppRouter._();

  static const home = '/';
  static const community = '/community';
  static const settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRouter.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case AppRouter.community:
        final args = settings.arguments as CommunityScreenArgs;
        return MaterialPageRoute(builder: (_) => CommunityScreen(args: args));
      case AppRouter.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
