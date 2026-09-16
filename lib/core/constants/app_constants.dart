/// Central place for every tunable MVP constant. Nothing below should be
/// hard-coded again anywhere else in the app.
class AppConstants {
  AppConstants._();

  // --- Presence / heartbeat ---
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration presenceTimeout = Duration(minutes: 3);

  // --- Community lifecycle ---
  static const Duration dormantTtl = Duration(minutes: 45);

  // --- Location sharing (supplier) ---
  static const Duration locationUpdateInterval = Duration(seconds: 20);
  static const double locationUpdateDistanceMeters = 30;
  static const Duration supplierReportTtl = Duration(minutes: 3);

  // --- Rate limiting ---
  static const Duration minCommunityCreationGap = Duration(seconds: 30);
  static const Duration minLocationReportGap = Duration(seconds: 10);

  // --- Search ---
  static const int maxSearchSuggestions = 10;
  static const int minSearchLength = 1;

  // --- Map ---
  static const double mapMinZoom = 4;
  static const double mapMaxZoom = 19;
  static const double mapZoomStep = 1;

  // --- Firebase Realtime Database paths ---
  static const String communitiesPath = 'communities';
  static const String membersPath = 'communityMembers';
  static const String locationReportsPath = 'locationReports';
}
