# Production readiness audit

Audit date: 19 September 2026

## Verified in this workspace

- Flutter static analysis passes with no issues.
- Backend TypeScript type-check passes.
- All 27 backend unit tests pass.
- Mobile-width browser journey opens Home, Chats, Advocates, Courts and Groups.
- Local demo chat accepts a message and updates the conversation preview.
- Search controls, court actions, advocate actions and group creation entry points
  are present in the accessibility tree.

## Not yet verified end to end

The workstation has no Docker, PostgreSQL, Redis, MinIO or ClamAV installation.
The visible app therefore runs with `API_ENABLED=false`. None of the following may
be marked passed until the Compose stack is running and two independent accounts
and devices complete the journeys against the real API:

1. OTP request, verification, session refresh, logout and device revocation.
2. Advocate profile creation, verification and directory discovery.
3. Direct and group creation, membership removal and blocking races.
4. Message delivery, read receipts, reconnect, pagination and offline outbox retry.
5. Attachment upload, checksum validation, malware scanning, download and cleanup.
6. Court subscription and admin-only announcement publishing.
7. Realtime synchronization and opaque push registration.
8. Retention cleanup and append-only audit enforcement on PostgreSQL.

## Release blockers

### P0 — required before any customer production release

- Provision and test PostgreSQL, Redis, private object storage and ClamAV.
- Replace the development OTP code with restricted production provider credentials.
- Configure APNs/FCM delivery; registration alone does not deliver notifications.
- Run database migrations and backup/restore tests on staging.
- Execute two-account/two-device API tests, including reconnect and revoked-device
  cases, on Android hardware.
- Terminate TLS at the real reverse proxy and verify HTTP/WSS rejection paths.
- Add Flutter unit, widget and integration tests. There are currently no
  `test/*_test.dart` files.
- Complete Android signing, application ID, Play integrity/security review and
  dependency/vulnerability scanning.
- Publish privacy policy, terms, retention policy, account deletion/export flow
  and India-specific legal/compliance review for professional and personal data.

### P1 — required for a WhatsApp-like messaging experience

- Push notification delivery, notification preferences and deep linking.
- Typing indicators, online/last-seen controls and presence privacy.
- Reactions, delete-for-me and forwarding. Reply/quote, sender edit and
  delete-for-everyone are implemented but still require live two-account testing.
- Voice notes, camera/gallery capture, video and richer media previews.
- Message search, starred messages, pinned/archived/muted chats and unread markers.
- Group admin roles, invite links, mentions, polls, events and member permissions.
- Voice/video calls, call history and call safety controls if product scope requires it.
- Multi-device history synchronization and a tested backup/restore model.
- Spam reporting, abuse handling, rate limits beyond OTP and operational support tools.

## Security difference from WhatsApp

VakilSetu currently uses server-readable messaging by explicit product decision.
The service operator, database administrators and backups can read message and
attachment content. It must not be described as WhatsApp-equivalent privacy or
end-to-end encryption. Transport TLS and storage encryption reduce infrastructure
risk but do not change this trust model.

## UI observation

Browser automation confirmed that a demo message is added to the active group and
the conversation preview updates. The Flutter web accessibility value for the
composer remained populated after send. Confirm this visually on Android hardware;
if reproducible, treat composer clearing as a P1 UI defect.

## Release gate

Do not build or distribute a customer release APK yet. A debug/demo APK may be used
for design review only and must be clearly labelled as demo mode. The production
gate opens only when every P0 item has evidence attached to the release checklist.
