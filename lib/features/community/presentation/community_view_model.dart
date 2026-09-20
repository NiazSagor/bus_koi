import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bus_koi/core/constants/app_constants.dart';
import 'package:bus_koi/core/services/identity_service.dart';
import 'package:bus_koi/core/services/location_service.dart';
import 'package:bus_koi/features/community/data/community_repository.dart';
import 'package:bus_koi/features/settings/presentation/app_settings_provider.dart';
import 'package:bus_koi/shared/models/community.dart';
import 'package:bus_koi/shared/models/community_member.dart';
import 'package:bus_koi/shared/models/location_report.dart';

enum LocationSharePhase { idle, requestingPermission, permissionDenied, sharing }

/// Owns everything the community/map screen needs: presence heartbeat,
/// live member + location-report streams, and the supplier location
/// upload loop. One instance per community screen visit.
class CommunityViewModel extends ChangeNotifier {
  CommunityViewModel({
    required this.communityId,
    required this.displayName,
    required CommunityRepository repository,
    required IdentityService identity,
    required LocationService locationService,
    required AppSettingsProvider settings,
  })  : _repository = repository,
        _identity = identity,
        _locationService = locationService,
        _settings = settings;

  final String communityId;
  final String displayName;
  final CommunityRepository _repository;
  final IdentityService _identity;
  final LocationService _locationService;
  final AppSettingsProvider _settings;

  StreamSubscription<List<CommunityMember>>? _membersSub;
  StreamSubscription<List<LocationReport>>? _reportsSub;
  StreamSubscription<Community?>? _communitySub;
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  Timer? _periodicUploadTimer;
  Position? _lastKnownPosition;
  DateTime? _lastReportSentAt;

  List<CommunityMember> members = [];
  List<LocationReport> locationReports = [];
  Community? community;
  LocationSharePhase sharePhase = LocationSharePhase.idle;
  bool disposed = false;
  bool abuseReported = false;

  /// When this community will go dormant if nothing keeps it active in the
  /// meantime — null until the community's own record has loaded.
  DateTime? get dormantAt => community?.lastActiveAt.add(AppConstants.dormantTtl);

  Duration? get timeUntilDormant {
    final at = dormantAt;
    if (at == null) return null;
    final remaining = at.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get waitingCount =>
      members.where((m) => m.role == MemberRole.waiting).length;

  int get supplierCount =>
      members.where((m) => m.role == MemberRole.supplier).length;

  LocationReport? get latestReport =>
      locationReports.isEmpty ? null : locationReports.first;

  bool get isCurrentUserSupplier => sharePhase == LocationSharePhase.sharing;

  Future<void> initialize() async {
    final userId = await _identity.ensureSignedIn();
    await _repository.joinCommunity(communityId: communityId, userId: userId);

    _membersSub = _repository.watchMembers(communityId).listen((value) {
      members = value;
      _safeNotify();
    });
    _reportsSub = _repository.watchLocationReports(communityId).listen((value) {
      locationReports = value;
      _safeNotify();
    });
    _communitySub = _repository.watchCommunity(communityId).listen((value) {
      community = value;
      _safeNotify();
    });

    _heartbeatTimer = Timer.periodic(AppConstants.heartbeatInterval, (_) {
      _repository.sendHeartbeat(communityId: communityId, userId: userId);
    });
  }

  Future<void> leave() async {
    final userId = _identity.currentUserId;
    if (userId == null) return;
    await stopSharing();
    await _repository.leaveCommunity(communityId: communityId, userId: userId);
  }

  Future<bool> startSharingLocation() async {
    sharePhase = LocationSharePhase.requestingPermission;
    _safeNotify();

    final permission = await _locationService.requestPermission();
    if (permission != LocationPermissionResult.granted) {
      sharePhase = LocationSharePhase.permissionDenied;
      _safeNotify();
      return false;
    }

    final userId = _identity.currentUserId;
    if (userId == null) return false;

    await _repository.setRole(
      communityId: communityId,
      userId: userId,
      role: MemberRole.supplier,
    );

    sharePhase = LocationSharePhase.sharing;
    _safeNotify();

    final distanceFilter = _settings.batterySaver
        ? AppConstants.batterySaverDistanceMeters
        : AppConstants.locationUpdateDistanceMeters;
    final uploadInterval = _settings.batterySaver
        ? AppConstants.batterySaverLocationUpdateInterval
        : AppConstants.locationUpdateInterval;

    _positionSub = _locationService
        .positionStream(distanceFilterMeters: distanceFilter)
        .listen((position) {
      _lastKnownPosition = position;
      _maybeSendReport(userId, position);
    });

    _periodicUploadTimer = Timer.periodic(
      uploadInterval,
      (_) {
        final position = _lastKnownPosition;
        if (position != null) _maybeSendReport(userId, position);
      },
    );

    final initialPosition = await _locationService.currentPosition();
    if (initialPosition != null) {
      _lastKnownPosition = initialPosition;
      await _sendReport(userId, initialPosition);
    }

    return true;
  }

  void _maybeSendReport(String userId, Position position) {
    final last = _lastReportSentAt;
    if (last != null &&
        DateTime.now().difference(last) < AppConstants.minLocationReportGap) {
      return;
    }
    _sendReport(userId, position);
  }

  Future<void> _sendReport(String userId, Position position) async {
    _lastReportSentAt = DateTime.now();
    await _repository.submitLocationReport(
      communityId: communityId,
      supplierId: userId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speedMps: position.speedAccuracy > 0 ? position.speed : null,
    );
  }

  Future<void> reportAbuse() async {
    final userId = _identity.currentUserId;
    if (userId == null || abuseReported) return;
    abuseReported = true;
    _safeNotify();
    await _repository.reportAbuse(communityId: communityId, reporterId: userId);
  }

  Future<void> stopSharing() async {
    _positionSub?.cancel();
    _positionSub = null;
    _periodicUploadTimer?.cancel();
    _periodicUploadTimer = null;

    final userId = _identity.currentUserId;
    if (userId != null && sharePhase == LocationSharePhase.sharing) {
      await _repository.stopSharing(communityId: communityId, supplierId: userId);
    }
    sharePhase = LocationSharePhase.idle;
    _safeNotify();
  }

  void _safeNotify() {
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    _membersSub?.cancel();
    _reportsSub?.cancel();
    _communitySub?.cancel();
    _positionSub?.cancel();
    _heartbeatTimer?.cancel();
    _periodicUploadTimer?.cancel();
    super.dispose();
  }
}
