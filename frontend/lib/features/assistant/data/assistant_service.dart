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

/// A task snapshot returned by an executed assistant action.
class AssistantTaskInfo {
  const AssistantTaskInfo({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.dueDate,
    this.reminderAt,
    this.course,
    this.description,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final DateTime? reminderAt;
  final String? course;
  final String? description;
  final List<String> tags;

  static AssistantTaskInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? raw['_id']?.toString();
    final title = raw['title'];
    if (id == null || id.isEmpty || title is! String) return null;
    return AssistantTaskInfo(
      id: id,
      title: title,
      status: raw['status']?.toString() ?? 'todo',
      priority: raw['priority']?.toString() ?? 'medium',
      dueDate: raw['dueDate'] is String
          ? DateTime.tryParse(raw['dueDate'] as String)
          : null,
      reminderAt: raw['reminderAt'] is String
          ? DateTime.tryParse(raw['reminderAt'] as String)
          : null,
      course: raw['course'] is String ? raw['course'] as String : null,
      description: raw['description'] is String
          ? raw['description'] as String
          : null,
      tags: raw['tags'] is List
          ? raw['tags'].whereType<String>().toList()
          : const <String>[],
    );
  }
}

/// A pending action awaiting explicit user confirmation.
class AssistantPendingConfirmation {
  const AssistantPendingConfirmation({
    required this.pendingActionId,
    required this.type,
    required this.summary,
    this.task,
    this.expiresAt,
  });

  final String pendingActionId;
  final String type;
  final String summary;
  final AssistantTaskInfo? task;
  final DateTime? expiresAt;

  static AssistantPendingConfirmation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['pendingActionId']?.toString();
    if (id == null || id.isEmpty) return null;
    return AssistantPendingConfirmation(
      pendingActionId: id,
      type: raw['type']?.toString() ?? 'unknown',
      summary: raw['summary']?.toString() ?? 'Confirm this action?',
      task: AssistantTaskInfo.fromJson(raw['task']),
      expiresAt: raw['expiresAt'] is String
          ? DateTime.tryParse(raw['expiresAt'] as String)
          : null,
    );
  }
}

/// Which screens should reload after an action.
class AssistantRefresh {
  const AssistantRefresh({this.tasks = false, this.reminders = false});

  final bool tasks;
  final bool reminders;
}

/// Structured result of POST /api/assistant/act (and confirm/cancel-action).
///
/// [executed] is true ONLY when the backend actually persisted something;
/// [kind] distinguishes ordinary conversation from executed app actions.
class AssistantActResult {
  const AssistantActResult({
    required this.reply,
    required this.kind,
    required this.intent,
    required this.status,
    required this.executed,
    required this.changed,
    this.task,
    this.tasks = const <AssistantTaskInfo>[],
    this.reminder,
    this.confirmation,
    this.clarification,
    this.refresh = const AssistantRefresh(),
    this.appliedChanges,
  });

  final String reply;
  final String kind; // 'action' | 'conversation'
  final String intent;
  final String status; // executed | confirmation_required | clarification_required | not_found | failed | conversation
  final bool executed;
  final bool changed;
  final AssistantTaskInfo? task;
  final List<AssistantTaskInfo> tasks;
  final Object? reminder;
  final AssistantPendingConfirmation? confirmation;
  final String? clarification;
  final AssistantRefresh refresh;
  final Object? appliedChanges;

  bool get isAction => kind == 'action';
  bool get needsConfirmation =>
      status == 'confirmation_required' && confirmation != null;
  bool get isFailure => status == 'failed';

  static AssistantActResult fromJson(Map<String, dynamic> json) {
    final refresh = json['refresh'];
    return AssistantActResult(
      reply: json['reply']?.toString() ?? 'No response received.',
      kind: json['kind']?.toString() ?? 'conversation',
      intent: json['intent']?.toString() ?? 'conversation',
      status: json['status']?.toString() ?? 'conversation',
      executed: json['executed'] == true,
      changed: json['changed'] == true,
      task: AssistantTaskInfo.fromJson(json['task']),
      tasks: json['tasks'] is List
          ? (json['tasks'] as List)
                .map(AssistantTaskInfo.fromJson)
                .whereType<AssistantTaskInfo>()
                .toList()
          : const <AssistantTaskInfo>[],
      reminder: json['reminder'],
      confirmation: AssistantPendingConfirmation.fromJson(json['confirmation']),
      clarification: json['clarification'] is String
          ? json['clarification'] as String
          : null,
      refresh: AssistantRefresh(
        tasks: refresh is Map && refresh['tasks'] == true,
        reminders: refresh is Map && refresh['reminders'] == true,
      ),
      appliedChanges: json['appliedChanges'],
    );
  }
}

/// Encapsulates the assistant API calls. The request and response shape for
/// conversation stays `{ message }` -> `{ reply }`; task actions use the
/// confirmation- and ownership-safe `/api/assistant/act` pipeline.
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

  /// Full natural-language action pipeline. Sends the message; the backend
  /// recognises intent, validates, executes on the authenticated user's data,
  /// persists, and returns a truthful structured result.
  Future<AssistantActResult> act({
    required String token,
    required String message,
    List<Map<String, String>> context = const <Map<String, String>>[],
    String? currentDate,
    int? utcOffsetMinutes,
    String? clientRequestId,
  }) async {
    final data = await _api.postJson(
      ApiEndpoints.assistantAct,
      <String, dynamic>{
        'message': message,
        'context': context,
        'currentDate': ?currentDate,
        'utcOffsetMinutes': ?utcOffsetMinutes,
        'clientRequestId': ?clientRequestId,
      },
      token: token,
    );
    return AssistantActResult.fromJson(data);
  }

  /// Confirm a pending action (e.g. deletion). The backend re-validates
  /// ownership and executes exactly once.
  Future<AssistantActResult> confirmPendingAction({
    required String token,
    required String pendingActionId,
  }) async {
    final data = await _api.postJson(
      ApiEndpoints.assistantConfirmAction,
      <String, dynamic>{'pendingActionId': pendingActionId},
      token: token,
    );
    return AssistantActResult.fromJson(data);
  }

  /// Cancel a pending action; nothing executes.
  Future<AssistantActResult> cancelPendingAction({
    required String token,
    required String pendingActionId,
  }) async {
    final data = await _api.postJson(
      ApiEndpoints.assistantCancelAction,
      <String, dynamic>{'pendingActionId': pendingActionId},
      token: token,
    );
    return AssistantActResult.fromJson(data);
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
