import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AssistantTaskDraft {
  const AssistantTaskDraft({
    required this.title,
    this.description,
    this.course,
    this.dueDate,
    this.priority,
  });

  final String title;
  final String? description;
  final String? course;
  final DateTime? dueDate;
  final String? priority;
}

class AssistantDraftReply {
  const AssistantDraftReply({
    required this.reply,
    this.draft,
    this.clarification,
  });

  final String reply;
  final AssistantTaskDraft? draft;
  final String? clarification;
}

/// Encapsulates the assistant API call so the chat screen contains presentation
/// logic only. The request and response shape is unchanged from the backend
/// contract: `{ message }` -> `{ reply }`.
class AssistantService {
  AssistantService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<String> sendMessage({
    required String token,
    required String message,
    List<Map<String, String>> context = const <Map<String, String>>[],
  }) async {
    final data = await _api.postJson(ApiEndpoints.aiChat, <String, dynamic>{
      'message': message,
      'context': context,
    }, token: token);

    return data['reply'] as String? ?? 'No response received.';
  }

  Future<AssistantDraftReply> prepareTaskDraft({
    required String token,
    required String message,
    List<Map<String, String>> context = const <Map<String, String>>[],
  }) async {
    final data = await _api.postJson(ApiEndpoints.aiDraft, <String, dynamic>{
      'message': message,
      'context': context,
      'currentDate': DateTime.now().toIso8601String().substring(0, 10),
      'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    }, token: token);
    final raw = data['draft'];
    final draft = raw is Map<String, dynamic>
        ? AssistantTaskDraft(
            title: raw['title'] as String,
            description: raw['description'] as String?,
            course: raw['course'] as String?,
            dueDate: raw['dueDate'] is String
                ? DateTime.tryParse(raw['dueDate'] as String)
                : null,
            priority: raw['priority'] as String?,
          )
        : null;
    return AssistantDraftReply(
      reply: data['reply'] as String? ?? 'I could not prepare a task draft.',
      draft: draft,
      clarification: data['clarification'] as String?,
    );
  }
}
