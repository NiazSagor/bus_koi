import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import 'package:bus_koi/core/constants/app_constants.dart';
import 'package:bus_koi/core/utils/name_normalizer.dart';
import 'package:bus_koi/shared/models/community.dart';
import 'package:bus_koi/shared/models/community_member.dart';
import 'package:bus_koi/shared/models/location_report.dart';

/// The only piece of the app that knows about Firebase Realtime Database.
/// Everything above this talks in terms of [Community]/[CommunityMember]/
/// [LocationReport], so the backend could be swapped later without
/// touching UI or view-model code.
class CommunityRepository {
  CommunityRepository({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;
  final _uuid = const Uuid();

  DatabaseReference get _communities =>
      _db.ref(AppConstants.communitiesPath);
  DatabaseReference get _members => _db.ref(AppConstants.membersPath);
  DatabaseReference get _reports => _db.ref(AppConstants.locationReportsPath);

  // --- Search / discovery ---

  /// Active communities, most recently active first. Used for home-screen
  /// suggestions — there is no permanent bus list, only what is live now.
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

  // --- Create / join / leave ---

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

  // --- Members / presence ---

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

  // --- Location reports (supplier side) ---

  Future<void> submitLocationReport({
    required String communityId,
    required String supplierId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final report = LocationReport(
      supplierId: supplierId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      reportedAt: DateTime.now(),
    );
    // Latest-only: overwrite, never append. No movement history is stored.
    await _reports.child(communityId).child(supplierId).set(report.toMap());
    await _touchCommunity(communityId);
  }

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
}
