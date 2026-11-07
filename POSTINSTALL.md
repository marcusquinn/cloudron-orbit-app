**Create the root account.** When Orbit first starts it prints a one-time
setup link in the app's **Logs**. Open it to create the root account and your
first workspace. For a fresh link, run `orbit-setup-link` in the app's
**Terminal**. Treat the link as a password: whoever opens it first becomes the
root user.

**Set up email** in Orbit's **Admin → Email** page. Orbit needs it for
password resets, email changes, emailed invitations and open registration. Run
`orbit-mail-settings` in the Terminal for the Cloudron mail relay's values (the
output includes the relay password), choose **None (local relay only)** as the
encryption, save, and use **Send test email**. Run it again if mail stops after
the app's email settings change or the app is cloned.

**Invite your team** from **Settings → Members**. **Generate link** works
without email. Registration stays closed unless you open it in
**Admin → General**.

Keep backups of the app: `/app/data/secrets/app-key` decrypts the mail and
sign-in provider secrets Orbit stores.

Settings and commands: [README](https://github.com/marcusquinn/cloudron-orbit-app/blob/main/README.md).
