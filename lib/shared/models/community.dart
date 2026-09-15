enum CommunityStatus { active, dormant }

CommunityStatus communityStatusFromString(String? value) {
  switch (value) {
    case 'DORMANT':
      return CommunityStatus.dormant;
    case 'ACTIVE':
    default:
      return CommunityStatus.active;
  }
}

String communityStatusToString(CommunityStatus status) {
  switch (status) {
    case CommunityStatus.dormant:
      return 'DORMANT';
    case CommunityStatus.active:
      return 'ACTIVE';
  }
}

/// A temporary bus community. There is no permanent bus database — a
/// [Community] only exists while someone needs it.
class Community {
  const Community({
    required this.id,
    required this.displayName,
    required this.normalizedName,
    required this.status,
    required this.createdAt,
    required this.lastActiveAt,
    this.activeMemberCount = 0,
    this.activeSupplierCount = 0,
  });

  final String id;
  final String displayName;
  final String normalizedName;
  final CommunityStatus status;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  /// Derived client-side from community_members, not stored directly.
  final int activeMemberCount;
  final int activeSupplierCount;

  factory Community.fromMap(String id, Map<dynamic, dynamic> map) {
    return Community(
      id: id,
      displayName: map['displayName'] as String? ?? '',
      normalizedName: map['normalizedName'] as String? ?? '',
      status: communityStatusFromString(map['status'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? 0,
      ),
      lastActiveAt: DateTime.fromMillisecondsSinceEpoch(
        (map['lastActiveAt'] as num?)?.toInt() ?? 0,
      ),
      activeMemberCount: (map['memberCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'normalizedName': normalizedName,
      'status': communityStatusToString(status),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActiveAt': lastActiveAt.millisecondsSinceEpoch,
      'memberCount': activeMemberCount,
    };
  }

  Community copyWith({
    int? activeMemberCount,
    int? activeSupplierCount,
    CommunityStatus? status,
  }) {
    return Community(
      id: id,
      displayName: displayName,
      normalizedName: normalizedName,
      status: status ?? this.status,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt,
      activeMemberCount: activeMemberCount ?? this.activeMemberCount,
      activeSupplierCount: activeSupplierCount ?? this.activeSupplierCount,
    );
  }
}
