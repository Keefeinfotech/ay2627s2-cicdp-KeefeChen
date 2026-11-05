import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/calendar_event.dart';

/// Thin HTTP adapter for the backend calendar module.
///
/// The backend wraps payloads in `{ success, data }`, so parsing lives here and
/// the repository can stay concerned with merging remote and local events.
class CalendarApiDataSource {
  CalendarApiDataSource({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<CalendarEvent>> fetchEvents({
    required String token,
    required DateTime startDate,
    required DateTime endDate,
    String? groupId,
  }) async {
    final data = await _api.getJson(
      ApiEndpoints.calendar,
      token: token,
      query: <String, String>{
        'startDate': startDate.toUtc().toIso8601String(),
        'endDate': endDate.toUtc().toIso8601String(),
        if (groupId != null && groupId.trim().isNotEmpty)
          'groupId': groupId.trim(),
      },
    );

    final raw = data['data'];
    if (raw is! List) return const <CalendarEvent>[];

    return raw
        .map(CalendarEvent.tryFromJson)
        .whereType<CalendarEvent>()
        .toList(growable: false);
  }

  Future<CalendarEvent> createEvent({
    required String token,
    required CalendarEvent event,
  }) async {
    final data = await _api.postJson(
      ApiEndpoints.calendar,
      event.toCreateJson(),
      token: token,
    );

    final parsed = CalendarEvent.tryFromJson(data['data']);
    if (parsed == null) {
      throw ApiException(
        'The server returned an incomplete calendar event.',
        statusCode: 201,
      );
    }
    return parsed;
  }

  Future<List<CalendarEvent>> checkConflicts({
    required String token,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeId,
  }) async {
    final data = await _api.getJson(
      ApiEndpoints.calendarConflicts,
      token: token,
      query: <String, String>{
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        if (excludeId != null && excludeId.isNotEmpty) 'excludeId': excludeId,
      },
    );

    final payload = data['data'];
    final raw = payload is Map ? payload['conflictingEvents'] : null;
    if (raw is! List) return const <CalendarEvent>[];

    return raw
        .map(CalendarEvent.tryFromJson)
        .whereType<CalendarEvent>()
        .toList(growable: false);
  }
}
