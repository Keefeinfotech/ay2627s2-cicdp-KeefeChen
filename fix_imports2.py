import os

base = r'C:\Users\chenl\OneDrive\Desktop\CICD stuff\Assignment Submission\CA1_CICD_Project\frontend'

targets = [
    os.path.join(base, 'lib', 'features', 'calendar', 'presentation', 'pages', 'calendar_page.dart'),
    os.path.join(base, 'lib', 'features', 'home', 'widgets', 'dashboard_header.dart'),
    os.path.join(base, 'lib', 'features', 'profile', 'pages', 'profile_page.dart'),
    os.path.join(base, 'lib', 'features', 'projects', 'presentation', 'pages', 'projects_page.dart'),
    os.path.join(base, 'lib', 'features', 'reports', 'presentation', 'pages', 'reports_page.dart'),
    os.path.join(base, 'lib', 'features', 'onboarding', 'screens', 'onboarding_screen.dart'),
]

replacements = [
    ('core.widgets.', 'core/widgets/'),
    ('features.home.', 'features/home/'),
    ('features.authentication.', 'features/authentication/'),
    ('features.calendar.', 'features/calendar/'),
    ('features.projects.', 'features/projects/'),
    ('features.reports.', 'features/reports/'),
    ('features.task_management.', 'features/task_management/'),
    ('features.groups.', 'features/groups/'),
    ('features.reminders.', 'features/reminders/'),
    ('features.assistant.', 'features/assistant/'),
    ('features.profile.', 'features/profile/'),
    ('features.onboarding.', 'features/onboarding/'),
    ('home.data.task_repository.dart', 'home/data/task_repository.dart'),
    ('home.data.task_store.dart', 'home/data/task_store.dart'),
    ('home.data.gamification.dart', 'home/data/gamification.dart'),
    ('home.data.task_validation.dart', 'home/data/task_validation.dart'),
    ('home.models.task.dart', 'home/models/task.dart'),
    ('home.widgets.task_card.dart', 'home/widgets/task_card.dart'),
    ('home.widgets.task_editor.dart', 'home/widgets/task_editor.dart'),
    ('home.widgets.achievements_dialog.dart', 'home/widgets/achievements_dialog.dart'),
    ('home.widgets.dashboard_header.dart', 'home/widgets/dashboard_header.dart'),
    ('data.datasources.calendar_api_data_source.dart', 'data/datasources/calendar_api_data_source.dart'),
    ('data.models.calendar_event.dart', 'data/models/calendar_event.dart'),
    ('data.repositories.calendar_repository.dart', 'data/repositories/calendar_repository.dart'),
    ('domain.usecases.analyze_schedule.dart', 'domain/usecases/analyze_schedule.dart'),
    ('controllers.calendar_controller.dart', 'controllers/calendar_controller.dart'),
    ('authentication.data.auth_service.dart', 'authentication/data/auth_service.dart'),
    ('authentication.data.session_store.dart', 'authentication/data/session_store.dart'),
    ('authentication.models.session.dart', 'authentication/models/session.dart'),
    ('data.models.project.dart', 'data/models/project.dart'),
    ('data.models.report_snapshot.dart', 'data/models/report_snapshot.dart'),
    ('presentation.controllers.reports_controller.dart', 'presentation/controllers/reports_controller.dart'),
    ('presentation.controllers.calendar_controller.dart', 'presentation/controllers/calendar_controller.dart'),
    ('presentation.widgets.calendar_event_editor.dart', 'presentation/widgets/calendar_event_editor.dart'),
    ('presentation.widgets.calendar_views.dart', 'presentation/widgets/calendar_views.dart'),
    ('presentation.widgets.schedule_optimization_banner.dart', 'presentation/widgets/schedule_optimization_banner.dart'),
    ('presentation.widgets.report_charts.dart', 'presentation/widgets/report_charts.dart'),
    ("import 'package:frontend.features.", "import 'package:frontend/features/"),
]

for t in targets:
    with open(t, 'r', encoding='utf-8', errors='replace') as f:
        c = f.read()
    for old, new in replacements:
        c = c.replace(old, new)
    with open(t, 'w', encoding='utf-8', errors='replace') as f:
        f.write(c)
    print('done', t)
