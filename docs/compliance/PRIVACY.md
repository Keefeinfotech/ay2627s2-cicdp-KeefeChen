# Privacy Notice

Auxilia is a task manager. This notice explains what data the app handles, where
it is stored, and how to remove it. It describes the current development
version of the software.

## 1. Data the app handles

| Data | Purpose | Where it is stored |
|------|---------|--------------------|
| Tasks (title, notes, priority, due date, status, XP awarded flag) | Core task tracking | On your device only, in local preferences under the key `auxilia.tasks.v1.<owner>` |
| Account name (optional), email address | Sign-in and account identification | Backend MongoDB database |
| Password | Authentication | Stored only as a bcrypt hash; the plain password is never stored |
| Session token (JWT) | Keeps you signed in | Platform secure storage (Keychain, Keystore, or the browser's secure storage) |
| AI chat messages | Generate a response from the assistant | Sent to the Auxilia API when you use the assistant |

Tasks are keyed by owner on the device: guest tasks use `local`, and signed-in
tasks use the account email. Tasks are not uploaded to the backend.

## 2. Data the app does not collect

- No analytics, advertising identifiers, crash-reporting SDKs, or telemetry.
- No location, contacts, camera, microphone, or health data.
- No task content in server logs. The backend logs the HTTP method, path, and
  error message only.

## 3. AI assistant

When you send a message, the text and your session token are sent to the Auxilia
API. In the current release the API runs a mock provider that echoes the message
back; no third-party AI provider receives it. If a real provider is configured
in a future release, message text would be sent to that provider, and this notice
will be updated before that release ships.

Do not send passwords, financial data, or other sensitive personal information
to the assistant.

## 4. Storage and security

- Sign-in tokens are kept in platform secure storage rather than plain
  preferences.
- Passwords are hashed with bcrypt before storage.
- API traffic must use HTTPS in production.
- The API accepts only configured origins (CORS allowlist), applies rate
  limits, validates request bodies, and returns generic messages for unexpected
  server errors.
- Local task data is protected by the operating system's app sandbox. Anyone
  with access to an unlocked device and the app can read the tasks.

## 5. Retention

- Local tasks remain on the device until you delete them.
- The account record remains until the account is deleted.
- Session tokens remain until you sign out or the token expires.

## 6. Deleting your data

- Remove individual tasks with the delete action on each task.
- Remove all local tasks with **More options > Remove all local tasks** on the
  dashboard. This deletes the task list for the current owner on that device.
- Sign out to remove the session token from the device.
- Account deletion is not yet available in the app. To request deletion of an
  account and its email address, contact the maintainer privately using the
  channel in [SECURITY.md](../SECURITY.md). Do not post personal data in a
  public issue.

Clearing the app's storage or uninstalling the app also removes local tasks and
the stored session.

## 7. Children

Auxilia is not directed at children under 13 and does not knowingly collect
their personal data.

## 8. Changes

Material changes to this notice will be recorded in the repository history and
in the release notes. The current version applies from the date of the release
that includes it.
