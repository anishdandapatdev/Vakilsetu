# VakilSetu initial foundation

Status: architecture, guardrails and contracts implemented; no real authentication,
backend or E2EE implementation yet. Existing demo screens remain placeholders.
Home Concept 05 approved. Palette: solid navy, muted teal, slate blue, bronze on
white. No gradients. Remaining UI can be designed during app development.

## Structure and dependency rules
lib/main.dart is the composition entry point.
lib/app contains app routing/shell.
lib/design_system contains shared preview widgets and staged approved color tokens.
lib/features/<feature>/presentation contains UI.
lib/features/<feature>/domain contains pure Dart models and repository contracts.
lib/features/<feature>/application coordinates use cases.
lib/security contains the encryption-provider boundary.
Concrete data adapters belong in feature data/ directories when integrated.
Domain must never import Flutter, HTTP, cloud SDKs or platform storage libraries.
Presentation calls application/repository interfaces, not cloud SDKs or encryption primitives.
Old demo list widgets in design_system are transitional; replace in the UI stage.

A shared Flutter UI does not imply identical platform security.
Native secure storage and web storage implementations must remain separate adapters.

## Security decisions
- Require verified advocate status and a trusted device before private messaging.
- Pending advocates may complete onboarding and request verification.
- Verified badge is derived from backend approval, never self-selected.
- All direct/group contents, files and thumbnails must be end-to-end encrypted.
- Public court announcements are public, admin-authored content, not confidential E2EE.
- No plaintext private-message server search, server PDF preview or server AI processing.
- Local private search only. Push payloads contain opaque event IDs, no message previews.
- Newly linked devices and new group members do not automatically receive old keys.
- Default: no cloud history backup until user-controlled encrypted recovery is implemented.
- Resetting account credentials cannot recover message history by itself.
- Removing a device/member blocks future access; previously received content cannot be recalled.
- Block/report abuse; submitting selected decrypted messages as a report requires user consent.
- Protect device identity and session secrets in platform-appropriate storage.
- Encrypt local history and minimize plaintext document cache; app lock is supplemental.
- E2EE does not protect compromised endpoints, screenshots or all traffic metadata.
- Browser-delivered code is a trust boundary: strict CSP, no third-party scripts on
  messaging pages, controlled releases and dependency integrity checks are required.
- Admin authentication, authorization and audit trails are separate from advocate clients.

## Encryption selection gate
No library is selected or claimed audited at this stage.
Evaluate maintained interoperable messaging stacks first, rather than assembling
unrelated encryption libraries. Signal specifications and MLS are protocol references,
not drop-in Flutter dependencies. Verify implementation maintenance, license, audit
scope, mobile/web bindings, group membership, identity verification, offline delivery,
persistent ratchet state, recovery, large attachments and migration support.
Select ONE coherent interoperable stack after an Android-to-web proof of concept.
Do not implement cryptographic primitives or ratchets from these documents yourself.

References:
- https://signal.org/docs/specifications/doubleratchet/
- https://signal.org/docs/specifications/sesame/
- https://www.rfc-editor.org/info/rfc9420/
- https://mas.owasp.org/MASVS/

## Threat model
Assets: identity/device keys, message plaintext, attachment content, enrollment evidence.
Adversaries: unauthorized users, malicious members, stolen devices, compromised servers,
dependency/code-delivery attackers, abusive admins and network observers.
Trust: verified endpoint clients and their runtime, chosen E2EE library, recipient conduct.
Server is trusted for availability/authorization but must not possess private content keys.
Key substitution needs safety-number/QR verification and device-change warnings.
Revocation must reach existing sockets and downloads; stale cached membership is insufficient.

## Delivery phases
1. FOUNDATION (this change): modular preview, contracts, deny-by-default startup,
   policy tests, documented trust boundaries.
2. UI: implement approved Home and other screens with labeled local/demo adapters;
   loading, empty, error, offline, unverified and revoked states included.
3. ENCRYPTION SPIKE: select stack, prove Android/web direct chat and encrypted PDF,
   then groups, identity changes and linking before dynamic private-chat rollout.
4. DYNAMIC: real auth, approved profiles, directory, backend policies, realtime delivery,
   notifications, streaming encrypted files, admin, device revocation and recovery.
5. RELEASE: independent security review, remediation, signed APK/iOS/TestFlight,
   tested responsive web deployment and measured performance.

## Required release evidence
- Two real devices exchange text and files; server/logs/storage reveal no plaintext.
- Identity substitution detected; key-change confirmation behavior tested.
- Removed member/device cannot decrypt future content.
- Replay, tamper, stale epoch and out-of-order tests using the real SDK.
- Authenticated downloads and sockets reject IDOR and revoked credentials.
- Crash/retry cannot reuse ratchet state or produce duplicate logical sends.
- Password reset cannot decrypt earlier history.
- Large PDFs stream within a declared device memory budget.
- Browser XSS controls and native key storage validated separately.
- Admin MFA and role escalation tests; enrollment evidence access/retention tests.
- Independent review mapped to OWASP MASVS plus backend/web controls.

## Limits of tests
Policy tests use fake ciphertext exclusively to test orchestration. They are not
cryptographic tests, do not demonstrate E2EE, and must never be packaged as a provider.
The delivery service currently supports text only. Attachment contract, auth, directory,
profile approval and channel policies are integration boundaries, not connected features.
