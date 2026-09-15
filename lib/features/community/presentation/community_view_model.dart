import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bus_koi/core/constants/app_constants.dart';
import 'package:bus_koi/core/services/identity_service.dart';
import 'package:bus_koi/core/services/location_service.dart';
import 'package:bus_koi/features/community/data/community_repository.dart';
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
  })  : _repository = repository,
        _identity = identity,
        _locationService = locationService;

  final String communityId;
  final String displayName;
  final CommunityRepository _repository;
  final IdentityService _identity;
  final LocationService _locationService;

  StreamSubscription<List<CommunityMember>>? _membersSub;
  StreamSubscription<List<LocationReport>>? _reportsSub;
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  Timer? _periodicUploadTimer;
  Position? _lastKnownPosition;
  DateTime? _lastReportSentAt;

  List<CommunityMember> members = [];
  List<LocationReport> locationReports = [];
  LocationSharePhase sharePhase = LocationSharePhase.idle;
  bool disposed = false;

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

    _positionSub = _locationService
        .positionStream(
          distanceFilterMeters: AppConstants.locationUpdateDistanceMeters,
        )
        .listen((position) {
      _lastKnownPosition = position;
      _maybeSendReport(userId, position);
    });

    _periodicUploadTimer = Timer.periodic(
      AppConstants.locationUpdateInterval,
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
    );
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
    _positionSub?.cancel();
    _heartbeatTimer?.cancel();
    _periodicUploadTimer?.cancel();
    super.dispose();
  }
}
