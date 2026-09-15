import 'package:bus_koi/core/constants/app_constants.dart';

enum MemberRole { waiting, supplier }

MemberRole memberRoleFromString(String? value) {
  return value == 'SUPPLIER' ? MemberRole.supplier : MemberRole.waiting;
}

String memberRoleToString(MemberRole role) {
  return role == MemberRole.supplier ? 'SUPPLIER' : 'WAITING';
}

/// One user's membership in one community. `anonymous_user_id` is never
/// shown to other members — only aggregate counts and roles are surfaced.
class CommunityMember {
  const CommunityMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.lastSeenAt,
  });

  final String userId;
  final MemberRole role;
  final DateTime joinedAt;
  final DateTime lastSeenAt;

  bool get isActive =>
      DateTime.now().difference(lastSeenAt) < AppConstants.presenceTimeout;

  factory CommunityMember.fromMap(String userId, Map<dynamic, dynamic> map) {
    return CommunityMember(
      userId: userId,
      role: memberRoleFromString(map['role'] as String?),
      joinedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['joinedAt'] as num?)?.toInt() ?? 0,
      ),
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
        (map['lastSeenAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': memberRoleToString(role),
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'lastSeenAt': lastSeenAt.millisecondsSinceEpoch,
    };
  }
}
