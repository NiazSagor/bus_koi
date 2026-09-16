import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bus_koi/core/localization/gen/app_localizations.dart';
import 'package:bus_koi/core/routing/app_router.dart';
import 'package:bus_koi/core/services/connectivity_service.dart';
import 'package:bus_koi/core/services/identity_service.dart';
import 'package:bus_koi/core/services/location_service.dart';
import 'package:bus_koi/core/theme/app_theme.dart';
import 'package:bus_koi/features/community/data/community_repository.dart';
import 'package:bus_koi/features/community/data/mock_community_repository.dart';
import 'package:bus_koi/features/settings/presentation/locale_provider.dart';
import 'package:bus_koi/firebase_options.dart';

/// Flip to false once `flutterfire configure` has wired up a real Firebase
/// project. While true, the app runs entirely on in-memory seeded data
/// (see [MockCommunityRepository]) so the UI can be reviewed without a
/// backend.
const bool kUseMockData = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kUseMockData) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      // Firebase isn't configured yet (placeholder firebase_options.dart).
      // The app still boots so the UI can be reviewed; run
      // `flutterfire configure` before testing real data flows.
    }
  }

  final localeProvider = LocaleProvider();
  await localeProvider.load();

  runApp(BusKoiApp(localeProvider: localeProvider));
}

class BusKoiApp extends StatelessWidget {
  const BusKoiApp({super.key, required this.localeProvider});

  final LocaleProvider localeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        Provider<IdentityService>(create: (_) => IdentityService()),
        Provider<CommunityRepository>(
          create: (_) =>
              kUseMockData ? MockCommunityRepository() : FirebaseCommunityRepository(),
          dispose: (_, repo) {
            if (repo is MockCommunityRepository) repo.dispose();
          },
        ),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<ConnectivityService>(create: (_) => ConnectivityService()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, locale, _) {
          return MaterialApp(
            title: 'Bus Koi',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            locale: locale.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            initialRoute: AppRouter.home,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
