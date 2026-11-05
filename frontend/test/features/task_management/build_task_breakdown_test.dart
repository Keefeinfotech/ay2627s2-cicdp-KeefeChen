import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/task_management/data/models/task_breakdown.dart';
import 'package:frontend/features/task_management/domain/usecases/build_task_breakdown.dart';

void main() {
  const builder = BuildTaskBreakdown();

  test('builds an ordered, dependent plan with milestones', () {
    final plan = builder('Write the research essay', project: 'COMP 2101');

    expect(plan.sourceTitle, 'Write the research essay');
    expect(plan.summary, contains('COMP 2101'));
    expect(plan.subtasks, hasLength(7));
    expect(plan.milestones, <String>[
      'Research complete',
      'First draft ready',
      'Final review',
      'Submitted',
    ]);
    expect(plan.selectedCount, 7);
    expect(plan.selectedEffortMinutes, 250);
    expect(plan.selectedEffortLabel, '4.2 hr');

    for (var index = 0; index < plan.subtasks.length; index++) {
      final subtask = plan.subtasks[index];
      expect(subtask.order, index + 1);
      expect(subtask.milestone, isNotEmpty);
      expect(subtask.effortMinutes, greaterThan(0));
      if (index == 0) {
        expect(subtask.dependsOn, isEmpty);
      } else {
        expect(subtask.dependsOn, <String>[plan.subtasks[index - 1].id]);
      }
    }
  });

  test('uses a safe fallback title for empty input', () {
    final plan = builder('   ');

    expect(plan.sourceTitle, 'New task');
    expect(plan.summary, contains('New task'));
  });

  test('recalculates effort when steps are deselected', () {
    final plan = builder('Revise calculus');
    final List<SubtaskSuggestion> selected = plan.subtasks
        .map(
          (subtask) => subtask.id == 'draft'
              ? subtask.copyWith(selected: false)
              : subtask,
        )
        .toList(growable: false);
    final updated = plan.copyWith(subtasks: selected);

    expect(updated.selectedCount, 6);
    expect(updated.selectedEffortMinutes, 160);
    expect(updated.selectedEffortLabel, '2.7 hr');
    expect(plan.selectedCount, 7, reason: 'copyWith is immutable');
  });

  test('formats effort labels in minutes and hours', () {
    const short = SubtaskSuggestion(
      id: 'short',
      title: 'Short step',
      description: '',
      effortMinutes: 45,
      milestone: 'Milestone',
      order: 1,
    );
    const long = SubtaskSuggestion(
      id: 'long',
      title: 'Long step',
      description: '',
      effortMinutes: 90,
      milestone: 'Milestone',
      order: 2,
    );

    expect(short.effortLabel, '45 min');
    expect(long.effortLabel, '1.5 hr');
  });
}
