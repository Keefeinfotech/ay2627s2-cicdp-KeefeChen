# Accessibility

Accessibility is important to Auxilia because the application is designed to help students manage their academic and personal responsibilities. Users should be able to access essential features, manage tasks and receive reminders regardless of their abilities, devices or preferred methods of interaction.

Auxilia aims to provide an inclusive and user-friendly experience for all users, including individuals with visual, hearing, motor or cognitive accessibility needs. This document outlines the project's accessibility priorities, contributor expectations, issue-reporting procedures, supported environments, known limitations and continuous improvement practices.

## Priorities

Auxilia prioritises the following accessibility outcomes:

- **Visual Accessibility:** Use sufficient colour contrast, readable typography, appropriate text sizes and clear visual indicators. Information should not rely on colour alone to communicate task statuses or important notifications.
- **Keyboard Accessibility:** Ensure that essential features can be accessed and operated using a keyboard, particularly on the web platform. Interactive elements should have a clear and visible focus indicator.
- **Screen Reader Compatibility:** Provide meaningful labels for buttons, icons, form fields and other interactive elements so that users relying on screen readers can understand and navigate the application.
- **Content Clarity:** Use simple, consistent language, clear instructions and meaningful error messages to help users understand application features and recover from errors.
- **Responsive Accessibility:** Ensure that layouts and interactive elements remain usable across different screen sizes, device orientations and text scaling settings.
- **Consistent User Experience:** Maintain consistent navigation, component behaviour and interaction patterns across the mobile and web platforms.

Auxilia uses WCAG 2.2 Level AA as an aspirational accessibility target. This is a development goal and does not represent verified conformance. Accessibility evaluations will be required before any conformance claim can be made.

## Contributor expectations

All contributors should consider accessibility when developing or modifying user-facing features. Accessibility should be incorporated into the development process rather than treated as a separate improvement after implementation.

Contributors are expected to:

- Use semantic interface elements and provide meaningful labels for interactive components.
- Maintain sufficient colour contrast and avoid using colour as the only method of communicating information.
- Ensure that forms provide clear labels, validation messages and understandable error feedback.
- Support keyboard navigation and visible focus indicators for web-based interactions.
- Provide appropriate alternative text for meaningful images and accessible names for icon-only buttons.
- Check that layouts remain usable when text sizes are increased.
- Avoid unnecessary animations and provide suitable alternatives where motion may affect usability.
- Perform relevant accessibility checks and document any known limitations before submitting changes.

For user-facing contributions, developers should include relevant testing evidence in their pull requests, such as screenshots, test results, keyboard navigation checks or screen reader observations where applicable.

Accessibility-related checks should be incorporated into the development and quality assurance process. Automated checks can help identify common issues, but manual testing is also necessary to evaluate actual user interactions.

## Reporting accessibility issues

Users and contributors can report accessibility barriers through the Auxilia GitHub repository's issue tracker.

When reporting an issue, users are encouraged to provide:

- A description of the accessibility barrier.
- The feature or task they were attempting to complete.
- The affected page, screen or URL, where applicable.
- The observed behaviour and expected behaviour.
- The device, operating system and browser used.
- The assistive technology involved, if applicable.

Screenshots or screen recordings may be included to help explain the issue, but they are optional. Users are not required to disclose personal or medical information when reporting accessibility barriers.

### Severity

Accessibility issues can be categorised according to how significantly they affect a user's ability to use Auxilia.

| Severity | Description | Example |
|---|---|---|
| Critical | Prevents users from accessing essential features or completing important tasks, with no reasonable workaround. | A user cannot log in or create tasks because essential form controls are inaccessible. |
| High | Significantly affects the usability of an important feature, although an alternative method may exist. | A screen reader cannot identify important task action buttons. |
| Medium | Causes inconvenience or difficulty but does not completely prevent users from completing tasks. | Insufficient colour contrast makes certain secondary information difficult to read. |
| Low | Minor accessibility or usability issue with limited impact on the overall experience. | An icon has an unclear accessible description but its function is otherwise understandable. |

The development team will review and confirm the severity of reported issues during triage. Reporters do not need to determine the severity themselves.

### How we respond

The development team will review submitted accessibility issues, assess their impact and prioritise them according to severity and available development resources.

The response process will include:

1. **Acknowledgement:** Review the report and acknowledge the issue once it has been received and assessed.
2. **Investigation:** Attempt to reproduce the issue and identify the affected components or interactions.
3. **Prioritisation:** Assign an appropriate severity level and determine the necessary corrective actions.
4. **Resolution:** Implement and test an appropriate fix while considering the affected user experience.
5. **Verification:** Where practical, invite the reporter to confirm whether the barrier has been resolved.

If an immediate fix is not possible, the team will communicate the issue's status and provide a workaround where available. Updates will be provided through the relevant GitHub issue or pull request.

## Ownership and maintenance

The Auxilia project owner is responsible for overseeing accessibility considerations throughout the development lifecycle.

Responsibilities include:

- Reviewing accessibility requirements when planning new features.
- Ensuring that contributors follow the project's accessibility expectations.
- Reviewing reported accessibility issues and prioritising improvements.
- Verifying accessibility-related fixes during testing.
- Reviewing this accessibility statement when significant application changes are introduced.

Accessibility will be reviewed during feature development, sprint reviews and major releases. If project responsibilities are transferred, the incoming maintainer should also take ownership of existing accessibility issues, documentation and outstanding improvements.

## Supported environments

Auxilia is designed to support users across mobile and web platforms.

The following environments represent the project's intended testing targets:

| Platform | Target Environment |
|---|---|
| iOS | iOS 25 and later |
| Android | Android 15 and later |
| Web Browser | Google Chrome 140 and later |

The application aims to support:

- Touch interactions on mobile devices.
- Keyboard navigation on supported web interfaces.
- Screen readers and accessibility labels where supported by the platform.
- Increased text sizes and responsive layouts.
- Different screen dimensions and device orientations.

These environments are intended testing targets and should not be interpreted as proof that every device, browser or assistive technology combination has been fully evaluated.

## Known limitations

As Auxilia continues to develop, some accessibility limitations may remain in its current implementation.

Areas requiring further evaluation include:

- **Screen Reader Support:** Certain custom interactive components may require additional accessibility labels or semantic descriptions.
- **Keyboard Navigation:** Some interactive elements may require further testing to ensure consistent keyboard accessibility across the web platform.
- **Colour Contrast:** Certain interface elements, secondary text and status indicators may require contrast improvements.
- **Text Scaling:** Some layouts may require adjustments to prevent content from being clipped or overlapping when users increase text sizes.
- **Dynamic Feedback:** Task updates, synchronisation statuses and notifications may require additional announcements to ensure that screen reader users receive important feedback.

These areas will be reviewed as part of ongoing quality assurance. Identified barriers should be documented and tracked through the project's issue tracker, together with any available workarounds.

## Feedback and improvements

Auxilia welcomes feedback from users and contributors to improve its accessibility practices.

Suggestions for improving this accessibility statement, development guidelines or testing procedures can be submitted through the project's GitHub repository.

The development team will review feedback periodically and update this document when accessibility priorities, supported environments or development practices change.

Accessibility is an ongoing responsibility, and Auxilia aims to continuously improve its usability so that more users can independently access and benefit from its features.
