# VakilSetu

Responsive Flutter MVP for a verified advocate communication network. The same UI targets Android, iOS, and desktop web.

## Included

- OTP/email login entry
- Responsive mobile navigation and desktop sidebar
- Advocate search/directory with sober verified badges
- Direct/group conversation lists
- Admin-only public Delhi court channels
- Private groups and legal-network dashboard
- Approved Concept 05 solid navy, teal, slate blue and bronze design system
- Bundled Manrope/Inter fonts and scalable custom legal icons
- Working local search, group creation, chat composition and profile forms
- Sample document paging and zoom controls
- Separate admin UI with local status changes, announcements and activity

The current project is a front-end prototype using local demo data. Production OTP, Bar Council verification, messaging, upload/PDF preview, notifications, storage, and super-admin APIs require backend integration.

## Run

```sh
flutter pub get
flutter run -d chrome
```

Tap **Explore the demo** to open the workspace immediately. Alternatively, enter
a sample 10-digit number, tap **Send OTP**, then enter **123456**. No OTP is sent.
Debug and profile builds open the customer demo automatically. Release builds show
setup required unless they are explicitly built as a presentation demo.

## Foundation

See [architecture and security decisions](docs/FOUNDATION.md) before UI or backend work.
The legacy screens are now split into feature presentation modules. Domain interfaces
and the private-message use case are separate from Flutter widgets.

Run policy checks (no external test dependencies):

```sh
dart tool/security_policy_test.dart
dart analyze lib tool
```

The test encryption double is not cryptography. No real E2EE provider is implemented.

## Build

```sh
flutter build apk --debug

# Presentation-only web release
flutter build web --release --dart-define=DEMO_MODE=true

# Connected development build (server-readable messaging; no E2EE)
flutter run -d chrome --dart-define=API_ENABLED=true --dart-define=DEMO_MODE=false --dart-define=API_BASE_URL=http://127.0.0.1:8080/v1
```

Admin preview (separate entry point, no client-side role switch):

```sh
flutter run -d chrome -t lib/main_admin.dart
flutter build web --release -t lib/main_admin.dart --dart-define=DEMO_MODE=true --output=build/admin_web
```

See [UI stage report](docs/UI_STAGE.md) for checks and remaining integration work.
See [developer guide](DEVELOPER_GUIDE.md) for the split Flutter/backend architecture,
local test configuration, API integration order and production replacement checklist.
The API also has a [Dockerfile](backend/Dockerfile) and an optional
[`docker-compose.app.yml`](backend/docker-compose.app.yml) overlay. Flutter
remains a separate client and calls the containerized API; the developer guide
contains the Compose commands and configuration notes.

These commands build demos, not production-ready secure releases. Android release
signing is intentionally unconfigured; the template debug-key fallback was removed.
The iOS scaffold from the original generation is incomplete (no Xcode project).
Regenerate/verify it on a supported SDK setup before building; TestFlight also needs
macOS, Xcode and the owner's Apple Developer signing configuration.
