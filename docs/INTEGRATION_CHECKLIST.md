# Integration decisions for the dynamic phase

These are implementation gates, not claims about the current prototype.

| Area | Baseline | Before activation |
| --- | --- | --- |
| OTP/email | No real adapter | Provider account, abuse limits, expiring challenges, replay tests |
| Advocate approval | Backend authority only | Define reviewer process and evidence retention |
| Device enrollment | New devices start pending | Trusted-device QR approval, key change UI, revocation |
| Private messaging | Provider unavailable; send fails closed | Select licensed maintained E2EE stack, Android/web proof |
| Groups | Private group membership model | Atomic epoch changes, removal tests, no old-history sharing by default |
| Attachments | Ciphertext streaming contract only | SDK-integrated authenticated chunks, bounded previews, resumable upload |
| Public channels | Channel-scoped posting guard | Matching backend policies, author audit, read-only client UI |
| Admin | Separate boundary documented | Separate deployment/audience, MFA, least-privilege roles |
| Storage | No production storage configured | Region and retention decisions; authenticated downloads, quotas |
| Backup | Off by default | User-held recovery secret and independently reviewed restore design |
| Release | No secure release artifact | Signing, native/web validation, independent security review |

Do not add private-message plaintext to server-side analytics, search, OCR, malware
scanners or AI services without an explicit separate design and consent decision.
E2EE means server scanners cannot inspect private file contents. Safe local rendering,
file-size/type limits and recipient warnings are needed; MIME labels are untrusted.

Offline retry must use durable client message IDs, bounded queues and atomic crypto
state persistence. A removed member/device must not regain access by reconnecting.
Delivery/read receipts should be encrypted events where the selected protocol supports
them; presence and receipt controls belong in privacy settings.

Performance targets should be measured on representative Android devices, not promised
as zero lag. Paginate messages, virtualize lists, stream attachments, limit decoded
image/PDF caches, and keep heavy work away from UI frames.

The local policy helper cannot stop a modified client. Every sensitive rule must
also be enforced independently by backend authorization and the selected protocol.
