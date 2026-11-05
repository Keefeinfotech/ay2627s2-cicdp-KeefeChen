import os

base = r'C:\Users\chenl\OneDrive\Desktop\CICD stuff\Assignment Submission\CA1_CICD_Project\frontend'

fixes = [
    # (file, old, new)
    # calendar_page.dart fixes
    (os.path.join(base, 'lib', 'features', 'calendar', 'presentation', 'pages', 'calendar_page.dart'),
     "import '../../../../core/theme/app_typography.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'calendar', 'presentation', 'pages', 'calendar_page.dart'),
     "import 'package:frontend/core/widgets/app_snackbar.dart';\nimport 'package:frontend/features/authentication/models/session.dart';\n",
     ""),
    (os.path.join(base, 'lib', 'features', 'calendar', 'presentation', 'pages', 'calendar_page.dart'),
     "import 'package:frontend/features/home/data/task_repository.dart';",
     ""),
    # reports_page.dart fixes
    (os.path.join(base, 'lib', 'features', 'reports', 'presentation', 'pages', 'reports_page.dart'),
     "import '../../../../core/theme/app_typography.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'reports', 'presentation', 'pages', 'reports_page.dart'),
     "import 'package:frontend/core/widgets/app_snackbar.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'reports', 'presentation', 'pages', 'reports_page.dart'),
     "import 'package:frontend/features/home/data/task_repository.dart';",
     ""),
    # profile_page.dart fixes
    (os.path.join(base, 'lib', 'features', 'profile', 'pages', 'profile_page.dart'),
     "import 'package:frontend/core/theme/app_typography.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'profile', 'pages', 'profile_page.dart'),
     "import 'package:frontend/core/widgets/app_empty_state.dart';",
     ""),
    # task_management_page.dart fixes
    (os.path.join(base, 'lib', 'features', 'task_management', 'presentation', 'pages', 'task_management_page.dart'),
     "import 'package:frontend/core/theme/app_typography.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'task_management', 'presentation', 'pages', 'task_management_page.dart'),
     "import 'package:frontend/features/home/data/task_repository.dart';",
     ""),
    # projects_page.dart fixes
    (os.path.join(base, 'lib', 'features', 'projects', 'presentation', 'pages', 'projects_page.dart'),
     "import '../../../../core/theme/app_typography.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'projects', 'presentation', 'pages', 'projects_page.dart'),
     "import '../../../home/data/task_repository.dart';",
     ""),
    # home_screen.dart fixes
    (os.path.join(base, 'lib', 'features', 'home', 'screens', 'home_screen.dart'),
     "import '../../../core/theme/app_typography.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'home', 'screens', 'home_screen.dart'),
     "import '../../../core/widgets/app_status_badge.dart';",
     ""),
    # dashboard_header.dart fixes
    (os.path.join(base, 'lib', 'features', 'home', 'widgets', 'dashboard_header.dart'),
     "import 'package:frontend/core/theme/app_typography.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'home', 'widgets', 'dashboard_header.dart'),
     "import 'package:frontend/features/profile/widgets/profile_sheet.dart';",
     ""),
    # onboarding_screen.dart fixes
    (os.path.join(base, 'lib', 'features', 'onboarding', 'screens', 'onboarding_screen.dart'),
     "import 'package:frontend/core/theme/app_typography.dart';",
     ""),
    # login_screen.dart fixes
    (os.path.join(base, 'lib', 'features', 'authentication', 'screens', 'login_screen.dart'),
     "import '../../../core/theme/app_colors.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'authentication', 'screens', 'login_screen.dart'),
     "import '../../../core/theme/app_typography.dart';",
     ""),
    # signup_screen.dart fixes
    (os.path.join(base, 'lib', 'features', 'authentication', 'screens', 'signup_screen.dart'),
     "import '../../../core/theme/app_colors.dart';",
     ""),
    (os.path.join(base, 'lib', 'features', 'authentication', 'screens', 'signup_screen.dart'),
     "import '../../../core/theme/app_typography.dart';",
     ""),
    # app_shell.dart fixes
    (os.path.join(base, 'lib', 'core', 'layout', 'app_shell.dart'),
     "import 'package:frontend/features/home/data/api_task_repository.dart';",
     ""),
    # responsive_page_layout.dart fixes
    (os.path.join(base, 'lib', 'core', 'widgets', 'responsive_page_layout.dart'),
     "import 'package:path/path.dart';",
     ""),
    # api_task_repository.dart fixes
    (os.path.join(base, 'lib', 'features', 'home', 'data', 'api_task_repository.dart'),
     "import 'dart:convert';",
     ""),
]

for filepath, old, new in fixes:
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        c = f.read()
    c_before = c
    c = c.replace(old + '\n', new + '\n' if new else '')
    if c != c_before:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(c)
        print(f'Fixed {os.path.basename(filepath)}: removed {old[:60]}...')
