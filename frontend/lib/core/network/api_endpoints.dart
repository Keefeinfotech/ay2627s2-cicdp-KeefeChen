/// The single place that defines backend paths.
///
/// Paths are kept exactly as the existing Express API expects so the frontend
/// refactor does not change any backend contract.
abstract final class ApiEndpoints {
  static const String authSignup = '/api/auth/signup';
  static const String authLogin = '/api/auth/login';
  static const String aiChat = '/api/ai/chat';
  static const String aiDraft = '/api/ai/draft';
  static const String tasks = '/api/tasks';
  static String task(String id) => '/api/tasks/$id';
  static const String groups = '/api/groups';
  static String group(String id) => '/api/groups/$id';
  static String groupMembers(String id) => '/api/groups/$id/members';
  static const String invitations = '/api/invitations';
  static const String invitationAccept = '/api/invitations/accept';
  static const String calendar = '/api/calendar';
  static const String calendarConflicts = '/api/calendar/conflicts';
}
