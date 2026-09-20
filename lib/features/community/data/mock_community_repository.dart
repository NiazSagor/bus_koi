import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'package:bus_koi/core/constants/app_constants.dart';
import 'package:bus_koi/core/utils/name_normalizer.dart';
import 'package:bus_koi/features/community/data/community_repository.dart';
import 'package:bus_koi/shared/models/community.dart';
import 'package:bus_koi/shared/models/community_member.dart';
import 'package:bus_koi/shared/models/location_report.dart';

/// In-memory stand-in for [FirebaseCommunityRepository], so the app can be
/// run and visualized before `flutterfire configure` has been done. Seeds a
/// handful of plausible Dhaka bus communities and simulates supplier
/// movement + presence on a timer so the UI looks alive, not static.
///
/// Swap back to [FirebaseCommunityRepository] in `main.dart` once a real
/// Firebase project is wired in.
class MockCommunityRepository implements CommunityRepository {
  MockCommunityRepository() {
    _seed();
    _simTimer = Timer.periodic(const Duration(seconds: 6), (_) => _simulateTick());
  }

  final _uuid = const Uuid();
  final _random = Random();

  final Map<String, Community> _communities = {};
  final Map<String, Map<String, CommunityMember>> _members = {};
  final Map<String, Map<String, LocationReport>> _reports = {};
  final Map<String, Set<String>> _abuseReporters = {};

  final _changes = StreamController<void>.broadcast();
  late final Timer _simTimer;

  void dispose() => _simTimer.cancel();

  void _notify() => _changes.add(null);

  // --- Seed data ---

  void _seed() {
    _seedCommunity(
      id: 'mock-8-number',
      name: '৮ নম্বর',
      minutesAgo: 2,
      waitingUsers: 6,
      suppliers: [
        _SeedSupplier(lat: 23.7808, lng: 90.4127), // Farmgate-ish
      ],
    );

    _seedCommunity(
      id: 'mock-bihongo',
      name: 'বিহঙ্গ পরিবহন',
      minutesAgo: 5,
      waitingUsers: 3,
      suppliers: [
        _SeedSupplier(lat: 23.8759, lng: 90.3795), // Uttara-ish
        _SeedSupplier(lat: 23.8623, lng: 90.3931),
      ],
    );

    _seedCommunity(
      id: 'mock-akash',
      name: 'আকাশ পরিবহন',
      minutesAgo: 1,
      waitingUsers: 9,
      suppliers: const [],
    );

    _seedCommunity(
      id: 'mock-shadhin',
      name: 'স্বাধীন',
      minutesAgo: 8,
      waitingUsers: 2,
      suppliers: [
        _SeedSupplier(lat: 23.7280, lng: 90.4125), // Motijheel-ish
      ],
    );
  }

  void _seedCommunity({
    required String id,
    required String name,
    required int minutesAgo,
    required int waitingUsers,
    required List<_SeedSupplier> suppliers,
  }) {
    final now = DateTime.now();
    final createdAt = now.subtract(Duration(minutes: minutesAgo + 20));
    final lastActiveAt = now.subtract(Duration(minutes: minutesAgo));

    _members[id] = {};
    _reports[id] = {};

    for (var i = 0; i < waitingUsers; i++) {
      final userId = 'mock-waiting-$id-$i';
      _members[id]![userId] = CommunityMember(
        userId: userId,
        role: MemberRole.waiting,
        joinedAt: createdAt,
        lastSeenAt: now,
      );
    }

    for (var i = 0; i < suppliers.length; i++) {
      final userId = 'mock-supplier-$id-$i';
      final supplier = suppliers[i];
      _members[id]![userId] = CommunityMember(
        userId: userId,
        role: MemberRole.supplier,
        joinedAt: createdAt,
        lastSeenAt: now,
      );
      _reports[id]![userId] = LocationReport(
        supplierId: userId,
        latitude: supplier.lat,
        longitude: supplier.lng,
        accuracy: 20 + _random.nextDouble() * 15,
        reportedAt: now,
        speedMps: 4 + _random.nextDouble() * 6, // ~15-35 km/h, plausible city bus speed
      );
    }

    _communities[id] = Community(
      id: id,
      displayName: name,
      normalizedName: NameNormalizer.normalize(name),
      status: CommunityStatus.active,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt,
      activeMemberCount: _members[id]!.length,
    );
  }

  /// Nudges every seeded supplier a little and refreshes presence so the
  /// demo keeps looking live instead of decaying past the real TTLs.
  void _simulateTick() {
    final now = DateTime.now();

    for (final communityId in _reports.keys.toList()) {
      final reports = _reports[communityId]!;
      for (final supplierId in reports.keys.toList()) {
        final current = reports[supplierId]!;
        // Small random walk, roughly +/-15m, so movement stays plausible.
        final jitterLat = (_random.nextDouble() - 0.5) * 0.0006;
        final jitterLng = (_random.nextDouble() - 0.5) * 0.0006;
        reports[supplierId] = LocationReport(
          supplierId: supplierId,
          latitude: current.latitude + jitterLat,
          longitude: current.longitude + jitterLng,
          accuracy: current.accuracy,
          reportedAt: now,
          speedMps: (3 + _random.nextDouble() * 8).clamp(0, 14),
        );
      }
    }

    for (final members in _members.values) {
      for (final userId in members.keys.toList()) {
        final m = members[userId]!;
        members[userId] = CommunityMember(
          userId: m.userId,
          role: m.role,
          joinedAt: m.joinedAt,
          lastSeenAt: now,
        );
      }
    }

    for (final id in _communities.keys.toList()) {
      final c = _communities[id]!;
      _communities[id] = c.copyWith(activeMemberCount: _members[id]?.length ?? 0);
    }

    _notify();
  }

  // --- Search / discovery ---

  @override
  Stream<List<Community>> watchActiveCommunities() async* {
    yield _activeCommunities();
    yield* _changes.stream.map((_) => _activeCommunities());
  }

  List<Community> _activeCommunities() {
    final list = _communities.values
        .where((c) => c.status == CommunityStatus.active)
        .toList()
      ..sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    return list;
  }

  @override
  Future<Community?> findActiveByNormalizedName(String normalizedName) async {
    for (final community in _communities.values) {
      if (community.normalizedName == normalizedName &&
          community.status == CommunityStatus.active) {
        return community;
      }
    }
    return null;
  }

  @override
  Stream<Community?> watchCommunity(String communityId) async* {
    yield _communities[communityId];
    yield* _changes.stream.map((_) => _communities[communityId]);
  }

  // --- Create / join / leave ---

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
    _communities[id] = community;
    _members[id] = {};
    _reports[id] = {};
    _notify();
    return community;
  }

  @override
  Future<void> joinCommunity({
    required String communityId,
    required String userId,
    MemberRole role = MemberRole.waiting,
  }) async {
    final members = _members.putIfAbsent(communityId, () => {});
    final now = DateTime.now();
    members[userId] = CommunityMember(
      userId: userId,
      role: role,
      joinedAt: members[userId]?.joinedAt ?? now,
      lastSeenAt: now,
    );
    _touchCommunity(communityId);
    _notify();
  }

  @override
  Future<void> leaveCommunity({
    required String communityId,
    required String userId,
  }) async {
    _members[communityId]?.remove(userId);
    _reports[communityId]?.remove(userId);
    _refreshMemberCount(communityId);
    _notify();
  }

  @override
  Future<void> sendHeartbeat({
    required String communityId,
    required String userId,
  }) async {
    final member = _members[communityId]?[userId];
    if (member == null) return;
    _members[communityId]![userId] = CommunityMember(
      userId: member.userId,
      role: member.role,
      joinedAt: member.joinedAt,
      lastSeenAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<void> setRole({
    required String communityId,
    required String userId,
    required MemberRole role,
  }) async {
    final member = _members[communityId]?[userId];
    if (member == null) return;
    _members[communityId]![userId] = CommunityMember(
      userId: member.userId,
      role: role,
      joinedAt: member.joinedAt,
      lastSeenAt: member.lastSeenAt,
    );
    _notify();
  }

  void _touchCommunity(String communityId) {
    final community = _communities[communityId];
    if (community == null) return;
    _communities[communityId] = community.copyWith(
      status: CommunityStatus.active,
      activeMemberCount: _members[communityId]?.length ?? 0,
    );
  }

  void _refreshMemberCount(String communityId) {
    final community = _communities[communityId];
    if (community == null) return;
    _communities[communityId] = community.copyWith(
      activeMemberCount: _members[communityId]?.length ?? 0,
    );
  }

  // --- Members / presence ---

  @override
  Stream<List<CommunityMember>> watchMembers(String communityId) async* {
    yield _activeMembers(communityId);
    yield* _changes.stream.map((_) => _activeMembers(communityId));
  }

  List<CommunityMember> _activeMembers(String communityId) {
    final members = _members[communityId]?.values ?? const <CommunityMember>[];
    return members.where((m) => m.isActive).toList();
  }

  // --- Location reports (supplier side) ---

  @override
  Future<void> submitLocationReport({
    required String communityId,
    required String supplierId,
    required double latitude,
    required double longitude,
    required double accuracy,
    double? speedMps,
  }) async {
    final reports = _reports.putIfAbsent(communityId, () => {});
    reports[supplierId] = LocationReport(
      supplierId: supplierId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      reportedAt: DateTime.now(),
      speedMps: speedMps,
    );
    _touchCommunity(communityId);
    _notify();
  }

  @override
  Future<void> stopSharing({
    required String communityId,
    required String supplierId,
  }) async {
    _reports[communityId]?.remove(supplierId);
    await setRole(
      communityId: communityId,
      userId: supplierId,
      role: MemberRole.waiting,
    );
  }

  @override
  Stream<List<LocationReport>> watchLocationReports(String communityId) async* {
    yield _freshReports(communityId);
    yield* _changes.stream.map((_) => _freshReports(communityId));
  }

  List<LocationReport> _freshReports(String communityId) {
    final reports = _reports[communityId]?.values ?? const <LocationReport>[];
    return reports.where((r) => !r.isStale).toList()
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
  }

  // --- Abuse reporting ---

  @override
  Future<void> reportAbuse({
    required String communityId,
    required String reporterId,
  }) async {
    final reporters = _abuseReporters.putIfAbsent(communityId, () => {});
    reporters.add(reporterId);

    if (reporters.length >= AppConstants.abuseReportThreshold) {
      final community = _communities[communityId];
      if (community != null) {
        _communities[communityId] = community.copyWith(status: CommunityStatus.dormant);
      }
    }
    _notify();
  }
}

class _SeedSupplier {
  const _SeedSupplier({required this.lat, required this.lng});
  final double lat;
  final double lng;
}
