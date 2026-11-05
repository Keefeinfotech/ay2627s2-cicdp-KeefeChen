import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/group.dart';

/// Thin, typed wrapper around the group, member and invitation endpoints.
class GroupsRepository {
  GroupsRepository({required this.token, ApiClient? api})
    : _api = api ?? ApiClient();

  final String token;
  final ApiClient _api;

  Future<List<StudyGroup>> list({int page = 1, int limit = 50}) async {
    final response = await _api.getJson(
      ApiEndpoints.groups,
      token: token,
      query: <String, String>{'page': '$page', 'limit': '$limit'},
    );
    final payload = response['data'];
    final rawItems = payload is Map ? payload['items'] : payload;
    if (rawItems is! List) return const <StudyGroup>[];

    return rawItems
        .map(StudyGroup.tryFromJson)
        .whereType<StudyGroup>()
        .toList(growable: false);
  }

  Future<StudyGroup> create({
    required String name,
    String description = '',
    bool isPublic = false,
  }) async {
    final response = await _api.postJson(ApiEndpoints.groups, <String, dynamic>{
      'name': name.trim(),
      if (description.trim().isNotEmpty) 'description': description.trim(),
      'visibility': isPublic ? 'PUBLIC' : 'PRIVATE',
    }, token: token);
    final group = StudyGroup.tryFromJson(response['data']);
    if (group == null) {
      throw ApiException('The server returned an incomplete group.');
    }
    return group;
  }

  Future<StudyGroup> update(
    String groupId, {
    required String name,
    String description = '',
    bool isPublic = false,
  }) async {
    final response = await _api
        .patchJson(ApiEndpoints.group(groupId), <String, dynamic>{
          'name': name.trim(),
          'description': description.trim(),
          'visibility': isPublic ? 'PUBLIC' : 'PRIVATE',
        }, token: token);
    final group = StudyGroup.tryFromJson(response['data']);
    if (group == null) {
      throw ApiException('The server returned an incomplete group.');
    }
    return group;
  }

  Future<void> archive(String groupId) async {
    await _api.deleteJson(ApiEndpoints.group(groupId), token: token);
  }

  Future<List<GroupMember>> members(String groupId) async {
    final response = await _api.getJson(
      ApiEndpoints.groupMembers(groupId),
      token: token,
      query: const <String, String>{'page': '1', 'limit': '100'},
    );
    final payload = response['data'];
    if (payload is! List) return const <GroupMember>[];

    return payload
        .map(GroupMember.tryFromJson)
        .whereType<GroupMember>()
        .toList(growable: false);
  }

  Future<GroupInvitation> invite({
    required String groupId,
    required String email,
    String role = 'MEMBER',
  }) async {
    final response = await _api.postJson(
      ApiEndpoints.invitations,
      <String, dynamic>{
        'groupId': groupId,
        'email': email.trim().toLowerCase(),
        'role': role,
      },
      token: token,
    );
    final invitation = GroupInvitation.tryFromJson(response['data']);
    if (invitation == null) {
      throw ApiException('The server returned an incomplete invitation.');
    }
    return invitation;
  }

  Future<void> accept(String token) async {
    await _api.postJson(ApiEndpoints.invitationAccept, <String, dynamic>{
      'token': token.trim(),
    }, token: this.token);
  }
}
