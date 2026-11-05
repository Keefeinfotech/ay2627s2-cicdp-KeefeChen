import '../../data/models/task_breakdown.dart';

/// Builds a structured execution plan for a task.
///
/// The backend exposes a free-form assistant reply rather than structured
/// actions, so this local planner supplies a deterministic, editable draft that
/// the user must approve before anything is created.
class BuildTaskBreakdown {
  const BuildTaskBreakdown();

  TaskBreakdownPlan call(String title, {String? project}) {
    final String cleanTitle = title.trim().isEmpty ? 'New task' : title.trim();
    final String scope = project?.trim().isNotEmpty == true
        ? ' for ${project!.trim()}'
        : '';

    return TaskBreakdownPlan(
      sourceTitle: cleanTitle,
      summary:
          'A four-stage plan for "$cleanTitle"$scope. Review each step, adjust '
          'the selection, then add the approved steps to your task list.',
      milestones: const <String>[
        'Research complete',
        'First draft ready',
        'Final review',
        'Submitted',
      ],
      subtasks: <SubtaskSuggestion>[
        const SubtaskSuggestion(
          id: 'clarify',
          title: 'Clarify the brief and success criteria',
          description:
              'List the deliverables, marking rubric and any constraints so '
              'the work starts against the right target.',
          effortMinutes: 20,
          milestone: 'Research complete',
          order: 1,
        ),
        const SubtaskSuggestion(
          id: 'research',
          title: 'Gather sources and notes',
          description:
              'Collect the strongest references, examples and data needed for '
              'the task. Note where each source will be used.',
          effortMinutes: 45,
          milestone: 'Research complete',
          order: 2,
          dependsOn: <String>['clarify'],
        ),
        const SubtaskSuggestion(
          id: 'outline',
          title: 'Create a working outline',
          description:
              'Turn the notes into a simple section-by-section structure with '
              'the key point for each section.',
          effortMinutes: 30,
          milestone: 'First draft ready',
          order: 3,
          dependsOn: <String>['research'],
        ),
        const SubtaskSuggestion(
          id: 'draft',
          title: 'Produce the first draft',
          description:
              'Write the full draft without polishing. Focus on completing the '
              'argument or deliverable end to end.',
          effortMinutes: 90,
          milestone: 'First draft ready',
          order: 4,
          dependsOn: <String>['outline'],
        ),
        const SubtaskSuggestion(
          id: 'review',
          title: 'Review against the brief',
          description:
              'Check each requirement, tighten the structure and correct any '
              'gaps before final proofreading.',
          effortMinutes: 35,
          milestone: 'Final review',
          order: 5,
          dependsOn: <String>['draft'],
        ),
        const SubtaskSuggestion(
          id: 'polish',
          title: 'Proofread and format',
          description:
              'Fix spelling, references, spacing and file naming. Confirm the '
              'submission format matches the instructions.',
          effortMinutes: 20,
          milestone: 'Final review',
          order: 6,
          dependsOn: <String>['review'],
        ),
        const SubtaskSuggestion(
          id: 'submit',
          title: 'Submit and archive a copy',
          description:
              'Upload the final file, confirm the receipt, and store a copy in '
              'the project folder.',
          effortMinutes: 10,
          milestone: 'Submitted',
          order: 7,
          dependsOn: <String>['polish'],
        ),
      ],
    );
  }
}
