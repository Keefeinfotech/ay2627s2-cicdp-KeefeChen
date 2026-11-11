import '../../../home/models/task.dart';
import '../../data/models/quick_add_preview.dart';

/// Converts a natural-language phrase such as
/// "Submit lab report tomorrow high priority for COMP 2101"
/// into structured task fields.
///
/// This is deliberately deterministic and local: the assistant may later
/// replace it with a server-side parser, but quick add must remain instant and
/// work offline.
class ParseQuickAdd {
  const ParseQuickAdd();

  QuickAddPreview call(
    String input, {
    List<String> projects = const <String>[],
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final String original = input.trim();
    String title = original;

    // Remove common conversational prefixes.
    const List<String> prefixes = <String>[
      'create a task to ',
      'create a task ',
      'add a task to ',
      'add a task ',
      'remind me to ',
      'i need to ',
      'todo:',
      'task:',
    ];
    for (final prefix in prefixes) {
      final pattern = RegExp(
        '^\\s*${RegExp.escape(prefix)}',
        caseSensitive: false,
      );
      title = title.replaceFirst(pattern, '');
    }

    TaskPriority priority = TaskPriority.medium;
    final String lower = title.toLowerCase();
    if (RegExp(r'\b(urgent|critical|high priority|asap|important)\b')
        .hasMatch(lower)) {
      priority = TaskPriority.high;
    } else if (RegExp(r'\b(low priority|whenever|someday)\b').hasMatch(lower)) {
      priority = TaskPriority.low;
    }

    String? project;
    for (final candidate in projects) {
      if (candidate.trim().isEmpty) continue;
      final escaped = RegExp.escape(candidate.trim());
      final projectPattern = RegExp(
        '(?:\\bfor|\\bin|\\bproject)\\s+$escaped\\b',
        caseSensitive: false,
      );
      if (projectPattern.hasMatch(title)) {
        project = candidate.trim();
        title = title.replaceFirst(projectPattern, '');
        break;
      }
    }

    // Hashtags become task tags. They are removed from the title so the
    // captured task reads naturally.
    final tags = <String>[];
    title = title.replaceAllMapped(RegExp(r'(?:^|\s)#([^\s#]{1,24})'), (match) {
      tags.add(match.group(1)!);
      return ' ';
    });

    final time = _parseTime(lower);
    DateTime? dueDate = _parseDate(lower, reference);
    if (dueDate != null && time != null) {
      dueDate = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        time.hour,
        time.minute,
      );
    } else if (dueDate == null && time != null) {
      final today = DateTime(
        reference.year,
        reference.month,
        reference.day,
        time.hour,
        time.minute,
      );
      dueDate = today.isAfter(reference)
          ? today
          : today.add(const Duration(days: 1));
    }
    if (dueDate != null) {
      title = _stripDatePhrase(title);
    }
    if (time != null) {
      title = _stripTimePhrase(title);
    }

    title = title
        .replaceAll(
          RegExp(
            r'\b(urgent|critical|high priority|low priority|asap|important|whenever|someday)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'[\s,.;:-]+$'), '')
        .replaceAll(RegExp(r'^[\s,.;:-]+'), '')
        .trim();

    if (title.isEmpty) title = original;

    final double confidence =
        (title.isNotEmpty && title != original ? 0.35 : 0.2) +
        (priority != TaskPriority.medium ? 0.2 : 0) +
        (dueDate != null ? 0.25 : 0) +
        (project != null ? 0.2 : 0) +
        (tags.isNotEmpty ? 0.1 : 0);

    return QuickAddPreview(
      title: title,
      priority: priority,
      dueDate: dueDate,
      project: project,
      tags: Task.normalizeTags(tags),
      originalText: original,
      confidence: confidence.clamp(0.25, 0.98),
    );
  }

  _ParsedTime? _parseTime(String lower) {
    final ampm = RegExp(
      r'\b(?:at|by|before)?\s*(\d{1,2})(?::([0-5]\d))?\s*(am|pm)\b',
    ).firstMatch(lower);
    if (ampm != null) {
      var hour = int.tryParse(ampm.group(1) ?? '') ?? 0;
      final minute = int.tryParse(ampm.group(2) ?? '0') ?? 0;
      final meridiem = ampm.group(3);
      if (hour < 1 || hour > 12) return null;
      if (meridiem == 'am') {
        if (hour == 12) hour = 0;
      } else if (hour != 12) {
        hour += 12;
      }
      return _ParsedTime(hour, minute);
    }

    final twentyFourHour = RegExp(
      r'\b(?:at|by|before)\s*([01]?\d|2[0-3]):([0-5]\d)\b',
    ).firstMatch(lower);
    if (twentyFourHour != null) {
      final hour = int.tryParse(twentyFourHour.group(1) ?? '') ?? 0;
      final minute = int.tryParse(twentyFourHour.group(2) ?? '0') ?? 0;
      return _ParsedTime(hour, minute);
    }

    if (RegExp(r'\b(noon|midday)\b').hasMatch(lower)) {
      return const _ParsedTime(12, 0);
    }
    if (RegExp(r'\bmidnight\b').hasMatch(lower)) {
      return const _ParsedTime(0, 0);
    }
    return null;
  }

  String _stripTimePhrase(String input) {
    return input
        .replaceAll(
          RegExp(
            r'\b(?:at|by|before)?\s*\d{1,2}(?::[0-5]\d)?\s*(?:am|pm)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(?:at|by|before)\s*(?:[01]?\d|2[0-3]):[0-5]\d\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\b(?:noon|midday|midnight)\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  DateTime? _parseDate(String lower, DateTime reference) {
    final DateTime today = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );

    if (RegExp(r'\btoday\b').hasMatch(lower)) {
      return today.add(const Duration(hours: 17));
    }
    if (RegExp(r'\btomorrow\b').hasMatch(lower)) {
      return today.add(const Duration(days: 1, hours: 17));
    }
    if (RegExp(r'\bnext week\b').hasMatch(lower)) {
      return today.add(const Duration(days: 7, hours: 17));
    }
    if (RegExp(r'\bnext month\b').hasMatch(lower)) {
      return DateTime(today.year, today.month + 1, today.day, 17);
    }
    if (RegExp(r'\btonight\b').hasMatch(lower)) {
      return today.add(const Duration(hours: 20));
    }

    final inDays = RegExp(r'\bin\s+(\d{1,2})\s+day[s]?\b').firstMatch(lower);
    if (inDays != null) {
      final days = int.tryParse(inDays.group(1) ?? '') ?? 1;
      return today.add(Duration(days: days, hours: 17));
    }

    final inWeeks = RegExp(r'\bin\s+(\d{1,2})\s+week[s]?\b').firstMatch(lower);
    if (inWeeks != null) {
      final weeks = int.tryParse(inWeeks.group(1) ?? '') ?? 1;
      return today.add(Duration(days: weeks * 7, hours: 17));
    }

    const List<String> weekdays = <String>[
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    for (var index = 0; index < weekdays.length; index++) {
      if (!RegExp('\\b${weekdays[index]}\\b').hasMatch(lower)) continue;
      final int targetWeekday = index + 1;
      int delta = targetWeekday - reference.weekday;
      if (delta <= 0) delta += 7;
      return today.add(Duration(days: delta, hours: 17));
    }

    final numericDate = RegExp(
      r'\b(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{2,4}))?\b',
    ).firstMatch(lower);
    if (numericDate != null) {
      final day = int.tryParse(numericDate.group(1) ?? '');
      final month = int.tryParse(numericDate.group(2) ?? '');
      final rawYear = numericDate.group(3);
      final year = rawYear == null
          ? today.year
          : (rawYear.length == 2
                ? 2000 + int.parse(rawYear)
                : int.parse(rawYear));
      if (day != null && month != null && month >= 1 && month <= 12) {
        return DateTime(year, month, day, 17);
      }
    }

    return null;
  }

  String _stripDatePhrase(String input) {
    return input
        .replaceAll(
          RegExp(
            r'\b(today|tomorrow|tonight|next week|next month)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\bin\s+\d{1,2}\s+(day|week)[s]?\b', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\b\d{1,2}[/\-]\d{1,2}([/\-]\d{2,4})?\b'), '');
  }
}

class _ParsedTime {
  const _ParsedTime(this.hour, this.minute);

  final int hour;
  final int minute;
}

/// Keeps the public use-case name explicit for callers and tests.
typedef ParseQuickAddUseCase = ParseQuickAdd;
