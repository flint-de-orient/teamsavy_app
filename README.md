# TeamSavy — mobile app

The Android and iOS app for the TeamSavy HR platform (app.teamsavy.com), built with Flutter. It mirrors the web app screen for screen — same pages, labels, statuses and "Atelier" design (Urbanist, ink→violet gradient, glass cards) — for two kinds of users:

- **Employees**: punch in/out with a selfie and location, attendance, leave, regularization, leave encashment, payslips, tax declarations, expenses, tasks & KPI, notices, documents.
- **HR / Tenant Admins**: dashboard, employees, appointments & hiring, leave/attendance/expense queues, payroll runs and statutory returns, and the settings pages.

Platform super-admin pages and the public candidate links (apply, exam, offer acceptance) stay web-only.

## How it talks to the server

The app uses the web app's own backend (`flintdoc-hr`), through a JSON layer added there under `/api/mobile/v1`:

- `POST /auth/login` (or `/auth/whatsapp/*`) returns the same session JWT the website uses as a cookie; the app sends it as `Authorization: Bearer <token>`.
- `GET /me` returns the user, enabled modules and the drawer links.
- Each screen reads `GET /api/mobile/v1/<same path as the web page>`.
- Mutations run the web's own server actions through `POST /api/mobile/v1/actions/<module>.<action>`, so validation and permissions are identical to the website.
- PDFs, CSVs and uploaded files come from the web's existing `/api/...` file routes.

That backend layer has to be deployed with the web app before a production build of this app works.

## Running it

Requirements: Flutter 3.29+ (Dart 3.7).

```bash
flutter pub get

# Against production (the default)
flutter run

# Against a local flintdoc-hr dev server
#   Android emulator:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
#   Physical phone over adb:
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

The server can also be changed at runtime: long-press the TeamSavy logo on the sign-in screen. Plain HTTP is only allowed to `localhost`, `127.0.0.1` and `10.0.2.2` (see `android/app/src/main/res/xml/network_security_config.xml`).

Release builds are currently signed with the debug key; add a real keystore before publishing to the Play Store.

## Code layout

```
lib/
  core/       API client, session, design tokens (from the web's globals.css), formatting
  widgets/    the design system: buttons, cards, badges, fields, MobileCard lists, ApiScreen
  shell/      topbar, sectioned drawer, bottom tabs, notifications, backdrop
  app/        router (paths are identical to the web URLs)
  features/   one folder per module: auth, dashboard, hiring, people, leave,
              attendance, payroll, expenses, tasks, settings
assets/       Urbanist font, logos, app icon sources
```

App icons are generated from `assets/icon/` with `dart run flutter_launcher_icons`.
