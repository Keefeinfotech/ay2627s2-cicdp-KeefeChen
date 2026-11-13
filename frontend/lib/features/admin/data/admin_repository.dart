import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../authentication/models/session.dart';
import 'models.dart';

/// User-safe failure message for administrative requests.
class AdminException implements Exception {
  AdminException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Client for the administrative API. Every call carries the caller's
/// access token; the backend remains the authority for permissions.
class AdminRepository {
  AdminRepository({String? token, ApiClient? api, Session? session})
    : _token = token ?? session?.token,
      _api = api ?? ApiClient();

  final String? _token;
  final ApiClient _api;

  Map<String, dynamic> _unwrap(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return data.cast<String, dynamic>();
      return response;
    }
    throw AdminException('The server returned an unexpected response.');
  }

  Never _wrap(dynamic error) {
    if (error is ApiException) {
      throw AdminException(error.message, statusCode: error.statusCode);
    }
    if (error is AdminException) throw error;
    throw AdminException('Something went wrong. Please try again.');
  }

  Future<AdminStats> fetchStats() async {
    try {
      final raw = await _api.getJson(ApiEndpoints.adminStats, token: _token);
      return AdminStats.fromJson(_unwrap(raw));
    } catch (error) {
      _wrap(error);
    }
  }

  Future<AdminUsersPageData> fetchUsers({
    String? search,
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final query = <String, String>{
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
      };
      final raw = await _api.getJson(
        ApiEndpoints.adminUsers,
        query: query,
        token: _token,
      );
      return AdminUsersPageData.fromJson(_unwrap(raw));
    } catch (error) {
      _wrap(error);
    }
  }

  Future<AdminUserSummary> updateUserStatus(
    String userId,
    String status,
  ) async {
    try {
      final raw = await _api.patchJson(
        ApiEndpoints.adminUserStatus(userId),
        <String, dynamic>{'status': status},
        token: _token,
      );
      return AdminUserSummary.fromJson(_unwrap(raw));
    } catch (error) {
      _wrap(error);
    }
  }
}
