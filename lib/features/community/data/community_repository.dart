import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import 'package:bus_koi/core/constants/app_constants.dart';
import 'package:bus_koi/core/utils/name_normalizer.dart';
import 'package:bus_koi/shared/models/community.dart';
import 'package:bus_koi/shared/models/community_member.dart';
import 'package:bus_koi/shared/models/location_report.dart';

/// Everything above the data layer (view models, screens) talks in terms of
/// this interface and the plain [Community]/[CommunityMember]/
/// [LocationReport] models, never Firebase types directly. See
/// [FirebaseCommunityRepository] for the real backend and
/// `mock_community_repository.dart` for the in-memory stand-in used before
/// a Firebase project is configured.
abstract class CommunityRepository {
  // --- Search / discovery ---

  /// Active communities, most recently active first. Used for home-screen
  /// suggestions — there is no permanent bus list, only what is live now.
  Stream<List<Community>> watchActiveCommunities();

  Future<Community?> findActiveByNormalizedName(String normalizedName);

  /// Live view of a single community's own record (status, lastActiveAt),
  /// used to show the dormant-TTL countdown.
  Stream<Community?> watchCommunity(String communityId);

  // --- Create / join / leave ---

  Future<Community> createCommunity(String displayName);

  Future<void> joinCommunity({
    required String communityId,
    required String userId,
    MemberRole role = MemberRole.waiting,
  });

  Future<void> leaveCommunity({
    required String communityId,
    required String userId,
  });

  Future<void> sendHeartbeat({
    required String communityId,
    required String userId,
  });

  Future<void> setRole({
    required String communityId,
    required String userId,
    required MemberRole role,
  });

  // --- Members / presence ---

  Stream<List<CommunityMember>> watchMembers(String communityId);

  // --- Location reports (supplier side) ---

  Future<void> submitLocationReport({
    required String communityId,
    required String supplierId,
    required double latitude,
    required double longitude,
    required double accuracy,
    double? speedMps,
  });

  Future<void> stopSharing({
    required String communityId,
    required String supplierId,
  });

  Stream<List<LocationReport>> watchLocationReports(String communityId);

  // --- Abuse reporting (basic anti-abuse safeguard, see prompt.md §32) ---

  /// Records one anonymous flag against a community from [reporterId]. Once
  /// [AppConstants.abuseReportThreshold] distinct reporters have flagged it,
  /// the community is marked dormant so it stops surfacing as active demand.
  /// Deliberately simple, per prompt.md: "do not attempt sophisticated fraud
  /// detection".
  Future<void> reportAbuse({
    required String communityId,
    required String reporterId,
  });
}

/// The only piece of the app that knows about Firebase Realtime Database.
class FirebaseCommunityRepository implements CommunityRepository {
  FirebaseCommunityRepository({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;
  final _uuid = const Uuid();

  DatabaseReference get _communities =>
      _db.ref(AppConstants.communitiesPath);
  DatabaseReference get _members => _db.ref(AppConstants.membersPath);
  DatabaseReference get _reports => _db.ref(AppConstants.locationReportsPath);
  DatabaseReference get _abuseReports => _db.ref(AppConstants.abuseReportsPath);

  @override
  Stream<List<Community>> watchActiveCommunities() {
    final query = _communities
        .orderByChild('status')
        .equalTo('ACTIVE');
    return query.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return <Community>[];
      final list = raw.entries
          .map((e) => Community.fromMap(e.key as String, e.value as Map))
          .toList()
        ..sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
      return list;
    });
  }

  @override
  Future<Community?> findActiveByNormalizedName(String normalizedName) async {
    final query = _communities
        .orderByChild('normalizedName')
        .equalTo(normalizedName);
    final snapshot = await query.get();
    final raw = snapshot.value;
    if (raw is! Map) return null;
    for (final entry in raw.entries) {
      final community = Community.fromMap(entry.key as String, entry.value as Map);
      if (community.status == CommunityStatus.active) return community;
    }
    return null;
  }

  @override
  Stream<Community?> watchCommunity(String communityId) {
    return _communities.child(communityId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return null;
      return Community.fromMap(communityId, raw);
    });
  }

  @override
  Future<Community> createCommunity(String displayName) async {
    final normalized = NameNormalizer.normalize(displayName);
    final existing = await findActiveByNormalizedName(normalized);
    if (existing != null) return existing;

    final id = _uuid.v4();
    final now = DateTime.now();
    final community = Community(
      id: id,
      displayName: displayName.trim(),
      normalizedName: normalized,
      status: CommunityStatus.active,
      createdAt: now,
      lastActiveAt: now,
    );
    await _communities.child(id).set(community.toMap());
    return community;
  }

  @override
  Future<void> joinCommunity({
    required String communityId,
    required String userId,
    MemberRole role = MemberRole.waiting,
  }) async {
    final existing = await _members.child(communityId).child(userId).get();
    final alreadyMember = existing.value != null;

    final now = DateTime.now();
    final member = CommunityMember(
      userId: userId,
      role: role,
      joinedAt: now,
      lastSeenAt: now,
    );
    await _members.child(communityId).child(userId).set(member.toMap());
    await _touchCommunity(communityId);
    if (!alreadyMember) {
      await _communities
          .child(communityId)
          .child('memberCount')
          .set(ServerValue.increment(1));
    }
  }

  @override
  Future<void> leaveCommunity({
    required String communityId,
    required String userId,
  }) async {
    final existing = await _members.child(communityId).child(userId).get();
    final wasMember = existing.value != null;

    await _members.child(communityId).child(userId).remove();
    await _reports.child(communityId).child(userId).remove();

    if (wasMember) {
      await _communities
          .child(communityId)
          .child('memberCount')
          .set(ServerValue.increment(-1));
    }
  }

  @override
  Future<void> sendHeartbeat({
    required String communityId,
    required String userId,
  }) async {
    await _members
        .child(communityId)
        .child(userId)
        .child('lastSeenAt')
        .set(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> setRole({
    required String communityId,
    required String userId,
    required MemberRole role,
  }) async {
    await _members
        .child(communityId)
        .child(userId)
        .child('role')
        .set(memberRoleToString(role));
  }

  Future<void> _touchCommunity(String communityId) async {
    await _communities.child(communityId).update({
      'status': 'ACTIVE',
      'lastActiveAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Stream<List<CommunityMember>> watchMembers(String communityId) {
    return _members.child(communityId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return <CommunityMember>[];
      return raw.entries
          .map((e) => CommunityMember.fromMap(e.key as String, e.value as Map))
          .where((m) => m.isActive)
          .toList();
    });
  }

  @override
  Future<void> submitLocationReport({
    required String communityId,
    required String supplierId,
    required double latitude,
    required double longitude,
    required double accuracy,
    double? speedMps,
  }) async {
    final report = LocationReport(
      supplierId: supplierId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      reportedAt: DateTime.now(),
      speedMps: speedMps,
    );
    // Latest-only: overwrite, never append. No movement history is stored.
    await _reports.child(communityId).child(supplierId).set(report.toMap());
    await _touchCommunity(communityId);
  }

  @override
  Future<void> stopSharing({
    required String communityId,
    required String supplierId,
  }) async {
    await _reports.child(communityId).child(supplierId).remove();
    await setRole(
      communityId: communityId,
      userId: supplierId,
      role: MemberRole.waiting,
    );
  }

  @override
  Stream<List<LocationReport>> watchLocationReports(String communityId) {
    return _reports.child(communityId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return <LocationReport>[];
      return raw.entries
          .map((e) => LocationReport.fromMap(e.key as String, e.value as Map))
          .where((r) => !r.isStale)
          .toList()
        ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    });
  }

  @override
  Future<void> reportAbuse({
    required String communityId,
    required String reporterId,
  }) async {
    await _abuseReports
        .child(communityId)
        .child(reporterId)
        .set(DateTime.now().millisecondsSinceEpoch);

    final snapshot = await _abuseReports.child(communityId).get();
    final raw = snapshot.value;
    final reportCount = raw is Map ? raw.length : 0;
    if (reportCount >= AppConstants.abuseReportThreshold) {
      await _communities.child(communityId).update({'status': 'DORMANT'});
    }
  }
}
