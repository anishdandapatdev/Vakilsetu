# Super Admin (reserved deployment boundary)

Implementation follows the approved UI stage. Use a separate entry point/deployment
and token audience; do not add a secret route or a client-side admin toggle to the
advocate app. Modules: verification queue, users, court announcements, audit history.
Strong MFA required. Permission decisions belong on the backend.
No private-message reader or decryption-key export will be implemented.
