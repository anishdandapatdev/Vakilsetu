# VakilSetu backend

NestJS modular backend for the VakilSetu Flutter clients and separate admin UI.
This folder is an executable API foundation. A local fixed-code OTP adapter is
available for development; production providers and a reviewed E2EE SDK remain
intentionally disabled until configured.

## Local start

1. Copy `.env.example` to `.env`. Its values are local-only; OTP is `123456`.
2. Start PostgreSQL and Redis with `docker compose up -d`.
3. Apply `migrations/001_initial.sql` to the `vakilsetu` database.
4. Run `npm install`, then `npm run start:dev`.
5. Check liveness at `GET http://127.0.0.1:8080/v1/health` and database
   readiness at `GET http://127.0.0.1:8080/v1/health/ready`.

Never commit `.env`. The example credentials are local-only and must not be used
in staging or production.

## Modules and trust boundaries

- `identity`: account, verification and trusted-device authorization.
- `messaging`: ciphertext envelope delivery only. Its endpoint currently returns
  HTTP 501 so private messaging cannot accidentally run without required checks.
- `health`: process health; dependency readiness will be added with DB adapters.
- `platform/config`: strict startup configuration and CORS allow-list.
- `migrations`: PostgreSQL schema with server-owned verification, device revocation,
  membership epochs, ciphertext idempotency, public channels and audit records.

The backend must never receive private message/file plaintext, conversation keys,
decrypted thumbnails, or notification previews. Authentication tokens identify an
account/device but do not replace E2EE identity keys.

## Implementation sequence

1. Database pool, transactional repositories, migration runner and readiness checks.
2. Replace the development OTP adapter with a real provider and monitored abuse controls.
3. Short-lived access sessions, rotating refresh sessions and device trust/revocation.
4. Profile submission and admin-controlled advocate verification.
5. Directory and court/public-announcement APIs.
6. E2EE protocol proof for Android and web; only then activate encrypted delivery.
7. Private encrypted object storage, resumable uploads and realtime WebSocket delivery.
8. Separate admin audience, MFA, least-privilege roles and immutable audit export.

Every sensitive authorization rule must be enforced by the server in the same
transaction as the state change or enqueue. Client UI state is never authoritative.

The full setup, architecture, integration order and production replacement checklist
are in `../DEVELOPER_GUIDE.md`.
