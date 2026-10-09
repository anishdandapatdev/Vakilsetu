# Server-readable messaging

This text-message path does **not** provide end-to-end encryption. The server,
database administrators and backups can read message bodies. Deploy behind HTTPS.
No encrypted-envelope contracts or storage were removed or repurposed.

## Setup

1. Back up the database and run backend `npm run migrate` to apply migration 008.
2. Start the backend using the existing developer guide.
3. Run Flutter with `API_ENABLED=true` and the correct `API_BASE_URL` build defines.
4. Use authenticated, verified accounts with trusted devices. Existing membership
   and blocked-account checks still apply; test keys do not bypass these checks.
5. Create conversations with the existing `/conversations/direct` or
   `/conversations/groups` API. Open those server conversations in the Chats list.

## API

- GET `/v1/conversations/:id/messages`: latest 100 messages, oldest first.
- GET `/v1/conversations`: server groups and direct chats, ordered by latest
  message, with `lastMessagePreview`, `lastMessageAt`, and `unreadCount`.
- POST same path: `{ "clientMessageId": "UUID", "body": "text" }`.
- Body limit: 4,000 characters. Reuse the UUID when retrying the same send.
- A repeated UUID with different content is rejected. UUIDs are scoped to sender
  and conversation. Every read/write checks current conversation membership.
- Replies reference a message in the same conversation. Senders may edit their
  messages for 15 minutes and delete them for everyone for two days. Deletion
  removes the stored body and attachment link; the object cleanup worker later
  removes an attachment that is no longer linked.
- GET `/v1/server-attachments` lists up to 50 recent clean files from active
  conversations. Pass the returned `nextCursor` as `before` for older files.
  Optional `search` (literal filename substring, up to 100 characters) and
  `kind=all|pdf|images` filters run on the server before pagination. Download
  authorization also requires an active, undeleted message link.

## Current limits

The backend emits the existing WebSocket `sync:available` signal to recipient
accounts and Flutter immediately refreshes the open conversation. Flutter also
polls active history every four seconds as a recovery fallback.
Failed text sends are retained in platform secure storage with their original
idempotency key and retried at startup or WebSocket reconnection. The outbox is
limited to 500 messages, scoped to the signed-in account, and does not silently
discard older unsent items. An older unscoped outbox key is deliberately not
auto-replayed because its sender cannot be authenticated after account switching;
inspect that legacy key manually before removing it on an upgraded device.
Pending replies retain their `replyToMessageId` when retried.
History is loaded in stable 50-message pages with a message-ID cursor. Delivery
is recorded when the recipient fetches a message. Read status is sent only when
that user's read-receipts setting is enabled. Server-readable PDF, JPEG and PNG
attachments up to 25 MB use signed object-storage transfers and active-membership
download checks. A successful send response means stored, not necessarily read.

Server-readable uploads require an S3-compatible object store that supports
SHA-256 payload checksums. Completion compares the provider-returned checksum and
object size; if an S3-compatible provider omits the checksum from `HEAD`, the
backend reads and hashes the object itself. Client metadata is never treated as
proof of content integrity. The presigned upload URL already carries checksum
and metadata query parameters; clients must not add duplicate unsigned
`x-amz-*` headers.
Unlinked pending or completed uploads older than 24 hours are claimed in locked
batches and deleted hourly. Failed object deletions restore the record for a
future retry. Attachments remain pending until malware scanning reports clean.
`MALWARE_SCANNER_PROVIDER=development` is a mock-clean scanner for local UI/API
work and is forbidden in production. Production should use `clamav` with a
reachable `CLAMAV_HOST`/`CLAMAV_PORT`; disabled or failing scanners fail closed.
Demo cards remain available but cannot send through the server API. The advocate
directory now creates direct server conversations and group creation uses the
verified advocates returned by the directory API. Incoming group messages show
the sender's server-owned advocate profile name. Initial history loading,
empty-error retry and stale-history retry states are represented explicitly.
The Groups tab lists server groups in connected mode. Sample groups remain in
the separate demo mode; they are never presented as server conversations.
For local-only two-account smoke tests, `node scripts/approve-local-message-test.js`
in `backend` approves only the reserved test phones ending `004` and `005` and
refuses production or non-loopback databases. Never use that fixture for real
advocate verification. With the local API running, execute
`node scripts/local-message-realtime-smoke.js` to test a WebSocket delivery
signal and recipient history using those reserved accounts.

Message retention is disabled unless `MESSAGE_RETENTION_DAYS` is explicitly set
to 30-3650 days. When enabled, the backend removes expired messages in bounded,
locked batches. Their now-unlinked attachment objects are subsequently removed by
the existing attachment cleanup worker. Choose and document the value with the
customer before enabling it; changing it can permanently delete message history.

Direct-message sends and block/unblock mutations lock the same conversation row.
Whichever transaction obtains that lock first completes first; after a block commits,
later sends fail authorization. Group removal already uses this same conversation
lock, so a removed member cannot send after the removal transaction commits.

Production startup forces HTTPS enforcement behind a configured trusted proxy.
Plain HTTP API traffic is rejected with HTTP 426 and realtime connections without
an HTTPS forwarded protocol are disconnected. Local development remains HTTP-capable.

Security-relevant session creation, device revocation, block/unblock, group
membership and advocate-verification decisions write metadata-only audit events.
Database triggers reject application updates or deletes to audit rows. Message
bodies, OTP values, tokens, filenames and attachment contents are never audit data.

Do not claim production readiness until database integration, two-account device
tests, live removal/blocking concurrency tests, an approved retention value and
the real reverse-proxy/TLS deployment are verified.
