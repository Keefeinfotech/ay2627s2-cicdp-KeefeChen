import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Encapsulates the assistant API call so the chat screen contains presentation
/// logic only. The request and response shape is unchanged from the backend
/// contract: `{ message }` -> `{ reply }`.
class AssistantService {
  AssistantService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<String> sendMessage({
    required String token,
    required String message,
  }) async {
    final data = await _api.postJson(ApiEndpoints.aiChat, <String, dynamic>{
      'message': message,
    }, token: token);

    return data['reply'] as String? ?? 'No response received.';
  }
}
