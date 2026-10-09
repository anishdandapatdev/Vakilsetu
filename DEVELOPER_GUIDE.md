# VakilSetu developer guide

This repository contains two applications kept in separate folders and connected
only through HTTP/WebSocket contracts:

- `lib/`, `android/`, `ios/`, `web/`: Flutter client.
- `backend/`: NestJS API and Socket.IO service.

The backend is never bundled into the APK. The Flutter app must receive its API
base URL at build/runtime configuration and call the separately deployed service.

## Trust boundary

The active messaging mode is server-readable: the backend authorizes membership
and stores message and attachment plaintext. Database administrators and backups
can therefore read it. HTTPS, storage encryption, least-privilege access, retention
and redacted logging are mandatory. Message bodies, OTPs, tokens and attachment
contents must never enter operational or audit logs.

Legacy encrypted-envelope code remains isolated and inactive; it is not a reviewed
E2EE implementation and must not be represented as providing end-to-end encryption.

## Local backend

### Containerized API (Flutter remains separate)

Copy `backend/.env.example` to `backend/.env`, then from `backend/` run:

```powershell
docker compose -f docker-compose.yml -f docker-compose.app.yml up --build -d
docker compose -f docker-compose.yml -f docker-compose.app.yml ps
```

This starts the NestJS API, PostgreSQL, Redis and MinIO. The API container
runs migrations before accepting traffic and listens on host port 8080. Stop
any separately running local API on that port first. Flutter is not included
in the image; use the Flutter command below to connect to the containerized API.
The Compose overlay uses local development credentials and is **not** a
production deployment. Before deployment, configure real secrets, HTTPS/TLS,
an externally reachable object-storage signing endpoint, CORS and providers.
`OBJECT_STORAGE_ENDPOINT` is internal to Docker; `OBJECT_STORAGE_PUBLIC_ENDPOINT`
is the URL signed for the Flutter client. The API reads objects through the
internal endpoint for malware scanning, so the browser-visible URL need not
resolve inside the container. For a physical device, replace the local public
endpoint with a host that the device can reach.

Without the overlay, the existing `docker compose up -d` continues to start
only PostgreSQL, Redis and MinIO for a host-run API.

Requirements: Node.js 20+, Docker Desktop and npm. PostgreSQL, Redis and a local
MinIO ciphertext store are supplied by Compose.

```powershell
cd backend
Copy-Item .env.example .env
docker compose up -d
npm install
npm run migrate
npm run start:dev
```

Check:

```text
GET http://127.0.0.1:8080/v1/health
GET http://127.0.0.1:8080/v1/health/ready
```

Local OTP is always `123456`. It is enabled by `OTP_PROVIDER=development`, prints
only to the backend console, and startup rejects this provider when
`NODE_ENV=production`.

## Local Flutter client

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_ENABLED=true --dart-define=API_BASE_URL=http://127.0.0.1:8080/v1
```

Android emulators normally reach the host through `http://10.0.2.2:8080/v1`.
A physical phone needs the development computer's LAN address, Android network
permission/configuration, and both devices on the same network. Production must use
HTTPS/WSS only.

The current UI still reads its preserved demo dataset. Do not delete or rename that
dataset while wiring repositories. Implement API-backed repositories behind the
existing domain interfaces, retaining the demo repository as an explicit demo/test
fixture rather than as a silent production fallback.

During debug/profile development, `PRESERVE_DEMO_DATA` defaults to true so the
approved customer advocates and bundled photos remain visible while server records
are added. Release builds default it to false. It can be selected explicitly with
`--dart-define=PRESERVE_DEMO_DATA=true|false`.

Without `API_ENABLED=true`, authentication intentionally keeps the existing customer
demo behavior. With it enabled, mobile OTP request/verification, secure session
persistence, refresh rotation and logout use the backend. Email authentication is
not advertised as working because the backend currently supports mobile OTP only.

## Backend capability map

- Identity: OTP challenge, session rotation, device trust/revocation.
- Advocates: profile submission, directory and verification state.
- Courts/announcements: public read APIs with admin-controlled publishing.
- Court subscriptions: authenticated per-account Join/Joined persistence.
- Messaging: direct/private-group membership and server-readable messages.
- Realtime: Socket.IO delivery hints, inbox synchronization and acknowledgements.
- Attachments: server-readable presigned storage, checksums and malware gating.
- Push: encrypted opaque device-token registration; provider delivery is pending.
- Admin: separate admin-session guard and verification operations.

Run verification after backend changes:

```powershell
npm run typecheck
npm test
npm run build
```

## Development-only values

`.env.example` contains non-secret local values. They are intentionally safe only
for a developer workstation. Never reuse them in staging or production, never
commit `.env`, and never place a real provider secret in Flutter code or an APK.

## Production replacement checklist

1. Create separate random session, OTP pepper, admin-session and push-encryption
   secrets in a managed secret store; rotate any shared development values.
2. Set `NODE_ENV=production`; production will reject the development OTP provider.
3. Configure a real OTP provider, its restricted credentials and abuse monitoring.
4. Configure managed PostgreSQL/Redis with TLS, backups, migrations and least-
   privilege service accounts.
5. Configure private S3-compatible storage, short presigned URL lifetimes, quotas,
   retention, checksum verification and a production malware scanner.
6. Complete device enrollment, revocation, membership-removal and offline retry tests.
7. Implement APNs/FCM delivery using opaque notification identifiers only.
8. Deploy the admin UI/API with a distinct audience, MFA and least-privilege roles.
9. Restrict CORS to exact deployed origins, terminate TLS, add rate limits and
   centralized redacted audit/operational logging.
10. Point Flutter at the production HTTPS API; remove any HTTP cleartext exception.
11. Run mobile security, backend authorization, dependency, restore and incident-
response reviews before signing a customer release.

### Production HTTPS boundary

The API listens on loopback HTTP and expects TLS to terminate at a reverse proxy.
Production automatically enables HTTPS enforcement and defaults
`TRUST_PROXY_HOPS=1`. The trusted proxy must replace (not append untrusted client
values to) `X-Forwarded-Proto` and forward `https`. Plain HTTP API requests receive
HTTP 426 and insecure realtime handshakes are disconnected. Set the exact proxy
depth to 1-3; never expose the loopback service directly or blindly trust arbitrary
forwarded headers. Local development keeps `REQUIRE_HTTPS=false` and
`TRUST_PROXY_HOPS=0`.

## Suggested Flutter integration order

1. Environment/API client and typed error mapping.
2. Authentication/session secure storage and refresh rotation.
3. Profile and advocate directory repositories.
4. Court channels and public announcements.
5. Device enrollment and revocation.
6. Server-readable conversations, receipts and durable offline retry.
7. Server-readable attachments.
8. Opaque push registration and reconnect synchronization.

Authentication, profiles, advocate directory, court listings, subscriptions and
public announcement reads are now wired in Flutter when `API_ENABLED=true`.
Conversation delivery remains the next client integration boundary.

The active messaging transport includes authenticated conversation metadata,
server-readable text, paged history, receipts, durable retry and Socket.IO refresh
signals. The legacy encrypted-envelope endpoints are not the active UI path.

Server-readable attachment transport uses presigned uploads/downloads, provider
checksum verification, strict size/type limits, malware scanning and cleanup of
unlinked objects. Local Compose supplies MinIO with development-only credentials.

Opaque FCM/APNs/WebPush token registration and revocation are wired as a repository;
provider SDK token acquisition and actual provider delivery remain intentionally
pending. Push payloads may carry only an opaque sync hint, never sender, court,
filename or message-preview text.

See `docs/FOUNDATION.md` and `docs/INTEGRATION_CHECKLIST.md` for the security gates
that remain mandatory even when a feature appears to work in the demo.
