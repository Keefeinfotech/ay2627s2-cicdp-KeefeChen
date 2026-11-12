// Admin platform statistics models. Mirrors the JSON contract of
// `GET /api/admin/stats` and `GET /api/admin/users` on the backend.

DateTime? _parseDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

class AdminTrendPoint {
  const AdminTrendPoint({required this.date, required this.count});

  final String date; // YYYY-MM-DD
  final int count;

  static AdminTrendPoint fromJson(Map<String, dynamic> json) => AdminTrendPoint(
    date: json['date'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}

class AdminUserStats {
  const AdminUserStats({
    required this.total,
    required this.active,
    required this.disabled,
    required this.pending,
    required this.newLast7Days,
  });

  final int total;
  final int active;
  final int disabled;
  final int pending;
  final int newLast7Days;

  static AdminUserStats fromJson(Map<String, dynamic> json) => AdminUserStats(
    total: (json['total'] as num?)?.toInt() ?? 0,
    active: (json['active'] as num?)?.toInt() ?? 0,
    disabled: (json['disabled'] as num?)?.toInt() ?? 0,
    pending: (json['pending'] as num?)?.toInt() ?? 0,
    newLast7Days: (json['newLast7Days'] as num?)?.toInt() ?? 0,
  );
}

class AdminTaskStats {
  const AdminTaskStats({
    required this.total,
    required this.todo,
    required this.inProgress,
    required this.completed,
    required this.archived,
    required this.completionRate,
    required this.createdLast7Days,
    required this.completedLast7Days,
  });

  final int total;
  final int todo;
  final int inProgress;
  final int completed;
  final int archived;

  /// Fraction of active tasks that are completed (0..1).
  final double completionRate;
  final int createdLast7Days;
  final int completedLast7Days;

  static AdminTaskStats fromJson(Map<String, dynamic> json) => AdminTaskStats(
    total: (json['total'] as num?)?.toInt() ?? 0,
    todo: (json['todo'] as num?)?.toInt() ?? 0,
    inProgress: (json['inProgress'] as num?)?.toInt() ?? 0,
    completed: (json['completed'] as num?)?.toInt() ?? 0,
    archived: (json['archived'] as num?)?.toInt() ?? 0,
    completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
    createdLast7Days: (json['createdLast7Days'] as num?)?.toInt() ?? 0,
    completedLast7Days: (json['completedLast7Days'] as num?)?.toInt() ?? 0,
  );
}

class AdminStats {
  const AdminStats({
    required this.users,
    required this.tasks,
    required this.taskCreationTrend,
    required this.taskCompletionTrend,
  });

  final AdminUserStats users;
  final AdminTaskStats tasks;
  final List<AdminTrendPoint> taskCreationTrend;
  final List<AdminTrendPoint> taskCompletionTrend;

  static AdminStats fromJson(Map<String, dynamic> json) => AdminStats(
    users: AdminUserStats.fromJson(
      (json['users'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    tasks: AdminTaskStats.fromJson(
      (json['tasks'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    taskCreationTrend: _trend(json['taskCreationTrend']),
    taskCompletionTrend: _trend(json['taskCompletionTrend']),
  );

  static List<AdminTrendPoint> _trend(Object? value) {
    if (value is! List) return const <AdminTrendPoint>[];
    return value
        .whereType<Map>()
        .map((point) => AdminTrendPoint.fromJson(point.cast<String, dynamic>()))
        .toList(growable: false);
  }
}

class AdminUserSummary {
  const AdminUserSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.createdAt,
    this.lastLoginAt,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String status; // active | disabled | pending
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  bool get isAdmin => role.toLowerCase() == 'admin';

  static AdminUserSummary fromJson(Map<String, dynamic> json) =>
      AdminUserSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        status: json['status'] as String? ?? 'active',
        createdAt: _parseDate(json['createdAt']),
        lastLoginAt: _parseDate(json['lastLoginAt']),
      );
}

class AdminUsersPageData {
  const AdminUsersPageData({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<AdminUserSummary> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  static AdminUsersPageData fromJson(Map<String, dynamic> json) =>
      AdminUsersPageData(
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => AdminUserSummary.fromJson(item.cast<String, dynamic>()),
            )
            .toList(growable: false),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      );
}
