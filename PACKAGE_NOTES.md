# VakilSetu source package

This archive contains the current Flutter frontend, Android/web project files,
assets, the separate NestJS backend, database migrations, Docker Compose files,
tests, and development guides. Generated build outputs and dependency caches are
excluded; restore them with `flutter pub get` and `npm ci` in `backend/`.
The existing iOS directory is included as-is, but it lacks a full Runner
scaffold (including `Info.plist`); iOS builds are not verified or claimed ready.

`backend/.env` is a copy of `.env.example` with **local-development-only**
settings and placeholder signing keys. The machine's existing `.env` and any
private credentials are not included. Replace all secrets and configure real
providers before any deployment. Never publish this development `.env`.

For a local connected run on Windows, start Docker Desktop, then run
`START_VAKILSETU_LOCAL.cmd`. See `DEVELOPER_GUIDE.md` for setup and architecture.

This is the current development source, **not a production release**. Admin MFA,
production OTP/push and malware-scanning providers, and release validation remain
pending. Server-readable messaging is used; E2EE and voice/video calls are not
implemented in this package.
