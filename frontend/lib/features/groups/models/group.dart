/// A study group returned by the group API.
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.visibility,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.role,
  });

  final String id;
  final String name;
  final String description;

  /// `PRIVATE` or `PUBLIC`.
  final String visibility;

  final String ownerId;

  /// The signed-in user's role in this group, when the API includes it.
  final String? role;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublic => visibility.toUpperCase() == 'PUBLIC';
  bool get isOwner => role?.toUpperCase() == 'OWNER';
  bool get canManage =>
      role?.toUpperCase() == 'OWNER' || role?.toUpperCase() == 'ADMIN';

  static StudyGroup? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['groupId'] ?? raw['_id'] ?? raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;

    final role = raw['role'];
    return StudyGroup(
      id: id,
      name: name.trim(),
      description: (raw['description'] as String?)?.trim() ?? '',
      visibility: (raw['visibility'] as String?) ?? 'PRIVATE',
      ownerId: (raw['ownerId'] as String?) ?? '',
      role: role is String ? role : null,
      createdAt: _date(raw['createdAt']),
      updatedAt: _date(raw['updatedAt']),
    );
  }

  static DateTime _date(Object? value) {
    if (value is! String) return DateTime.now();
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }
}

/// One active member of a group.
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.role,
    required this.status,
    required this.name,
    required this.email,
    required this.joinedAt,
  });

  final String userId;
  final String role;
  final String status;
  final String? name;
  final String? email;
  final DateTime joinedAt;

  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final address = email?.trim();
    if (address != null && address.isNotEmpty) return address;
    return 'Member';
  }

  String get initials {
    final source = displayName;
    final parts = source
        .split(RegExp(r'[\s@._-]+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  static GroupMember? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final userId = raw['userId'];
    if (userId is! String || userId.isEmpty) return null;

    return GroupMember(
      userId: userId,
      role: (raw['role'] as String?) ?? 'MEMBER',
      status: (raw['status'] as String?) ?? 'ACTIVE',
      name: raw['name'] as String?,
      email: raw['email'] as String?,
      joinedAt: raw['joinedAt'] is String
          ? (DateTime.tryParse(raw['joinedAt'] as String)?.toLocal() ??
                DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Result of creating a group invitation.
///
/// The backend currently returns the raw token so it can be delivered manually
/// until the email outbox worker is enabled.
class GroupInvitation {
  const GroupInvitation({
    required this.invitationId,
    required this.groupId,
    required this.email,
    required this.role,
    required this.token,
    required this.expiresAt,
  });

  final String invitationId;
  final String groupId;
  final String email;
  final String role;
  final String token;
  final DateTime expiresAt;

  static GroupInvitation? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final invitation = raw['invitation'];
    final token = raw['invitationToken'];
    if (invitation is! Map || token is! String || token.isEmpty) return null;

    final invitationId = invitation['invitationId'];
    final groupId = invitation['groupId'];
    if (invitationId is! String || groupId is! String) return null;

    return GroupInvitation(
      invitationId: invitationId,
      groupId: groupId,
      email: (invitation['email'] as String?) ?? '',
      role: (invitation['role'] as String?) ?? 'MEMBER',
      token: token,
      expiresAt: invitation['expiresAt'] is String
          ? (DateTime.tryParse(invitation['expiresAt'] as String)?.toLocal() ??
                DateTime.now().add(const Duration(days: 7)))
          : DateTime.now().add(const Duration(days: 7)),
    );
  }
}
