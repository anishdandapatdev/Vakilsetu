# UI stage delivery

## Design

Implemented the approved Home Concept 05 direction: white surfaces, solid navy,
muted teal, slate blue and warm bronze. No gradients. Manrope headings and Inter
body fonts are bundled locally with their OFL licenses.

Generated Profile/Directory, Chat/Documents, Courts/Groups/Settings and Admin
reference boards before implementing these screens. Auth used the earlier generated
Sign-in/OTP/Email board. Custom legal icons are scalable Flutter drawings derived
from the generated icon direction. Sample profile portraits use initials; uploaded
photos remain a later integration task.

## Implemented UI

- Responsive desktop sidebar and mobile navigation/drawer.
- Home with working navigation and directory search submission.
- Mobile/email sign-in forms, input validation, six-digit demo OTP and resend timer.
- Profile editing, sample avatar choice, court selector and pending verification state.
- Advocate search by name/court/enrollment/practice, court dropdown and profile dialog.
- Direct/group chat selection, local message composition, sample attachment picker.
- Private group creation with name and member selection.
- Public court list, local join/leave and read-only announcement detail.
- Document library filtering and simulated document preview with paging/zoom.
- Settings with local preference toggles, device-information dialog and sign-out.
- Separate admin entry with sample verification statuses, announcement composer and
  in-memory activity history. No private chat viewer or admin decryption capability.

## Verification

- Dart static analysis: no issues after implementation.
- Existing security policy tests: pass (not cryptographic tests).
- Release web builds succeeded for advocate and admin entry points.
- Desktop Home/sign-in and 390px mobile Home/chat layouts visually inspected.
- Search for Meera reduced the directory to one matching advocate.
- Creating Hearing prep with one colleague opened a two-member group chat.
- Composed a local message and verified its new bubble; no browser errors recorded.
- Channel detail had no composer and explicitly stated admin-only posting.
- Sample document controls moved from page 1 to page 2 and zoom 100% to 110%.
- Profile save returned to Home; verification remains pending after edits.
- Admin sample announcement appeared in the list and generated an activity entry;
  no browser errors recorded.

## Important boundaries

All UI state is in memory and resets on reload/sign-out. OTP/email flows are samples,
not authentication. Files are simulated previews, not a real PDF decoder. Device
upload, web drag-and-drop, real photo selection, cloud persistence, notifications,
device linking, account recovery and E2EE remain dynamic-phase integrations.

No APK or iOS build was produced in this UI stage. The Android project requires
its toolchain/signing checks and the incomplete iOS scaffold must be repaired on
a supported setup. The release web build is a demo artifact, not a secure production
deployment. The DEMO_MODE=false startup still denies access until services are wired.

## Source map

app/demo_store.dart: explicitly UI-only shared state.
design_system/ui.dart: shared palette, theme and widgets.
design_system/legal_icon.dart: custom vector drawing.
features/*/presentation/: screens.
admin/admin_preview.dart and main_admin.dart: isolated admin preview.
Security/domain/application contracts from the foundation remain intact.
