# Packaging decisions and upstream limitations

## Pinned runtime

Orbit 0.2.1: tag `v0.2.1`, commit `fe9dce7b155169cd02461d939dd0d6d8f9e50283`,
Apache-2.0. The image copies the `orbit` binary from upstream's release image
`ghcr.io/coollabsio/orbit:0.2.1`, pinned by its multi-arch index digest
`sha256:4ab1882b…7a81ce61` (full value in the Dockerfile). The image's revision
label matches the tag commit. The binary is a static (musl) Rust executable
with the web app embedded, so it runs on the Ubuntu-based `cloudron/base:6.0.1`
image, also pinned by digest. No upstream source is patched.

Packaging started on 0.2.0. Upstream published 0.2.1 on 2026-11-06 at 22:08 UTC
(23 commits later), so the pin moved before the first release. For the package
the relevant change is the content security policy, which now allows `blob:`
and Vimeo frames and `https:` media.

The package is x86-64 only: the catalog workflow builds `linux/amd64`.
Upstream publishes arm64 as well, and a local arm64 build of the Dockerfile
succeeded, but it has not been run or tested.

## Production mode behind Cloudron's proxy

In production Orbit requires a public origin, an app key and a list of trusted
proxies. It answers 400 `https_required` to any request a trusted proxy has not
marked as HTTPS, and refuses to start on an `ORBIT_*` variable it does not
know. Upstream's docs warn against trusting `0.0.0.0/0` or `::/0`.

Cloudron's proxy connects from the container's default gateway, and its health
checker sends no `X-Forwarded-Proto`. So Orbit listens on `127.0.0.1:8080` and
trusts only `127.0.0.1/32`, and nginx in the container listens on 8000
(`httpPort`) and:

- sets `X-Forwarded-Proto: https` on every request; Cloudron serves the app
  only over HTTPS;
- takes the client address from `X-Forwarded-For` only when the request comes
  from the default gateway, which `start.sh` reads from `/proc/net/route`
  (falling back to `172.18.0.1` with a log warning). Clients cannot forge their
  address, and other containers are seen as their own;
- streams uploads and downloads, leaves size limits to Orbit
  (`ORBIT_UPLOAD_MAX_*`, 25 MiB per file by default), and keeps WebSockets open
  for up to an hour.

The manifest's health check, `/health/ready`, answers 200 without signing in
once Orbit reports all its readiness checks ready.

On every start Orbit's MCP server logs a warning that an allowed origin without
a port matches any port, and that a future release will match only the
scheme's default port. Cloudron origins are always HTTPS on the default port,
so the future behaviour matches too; no change is needed.

## App key and secrets

Orbit encrypts the SMTP password and sign-in provider secrets it stores with
the app key. `start.sh` creates the key on first start
(`openssl rand -base64 32`) in `/app/data/secrets/app-key` (file 0600,
directory 0700), reuses it after that, and refuses to start if the file does
not hold base64 of 32 bytes. Cloudron backups include it; a restore without it
would leave those secrets unreadable.

## SQLite, not PostgreSQL

Upstream supports SQLite and PostgreSQL. PostgreSQL needs a database created
from `template0` with the `C.UTF-8` locale and the `unaccent` extension; whether
Cloudron's `postgresql` addon can provide that was not checked. The package
uses SQLite in WAL mode, declared as a Cloudron `localstorage` SQLite path so
backups take a consistent copy. That suits the small teams this testing release
is for. Full-text search uses SQLite FTS5 tables (`page_search`,
`chat_search`).

## Email

Orbit reads SMTP settings only from its own **Admin → Email** page, where they
are stored encrypted in the database; it has no environment configuration
([coollabsio/orbit#66](https://github.com/coollabsio/orbit/issues/66), open on
2026-11-06). So the package cannot configure Cloudron's mail relay itself.
`orbit-mail-settings` prints the relay's host, port, user, password and sender
for that page. A clone, or a change to the app's mail settings in Cloudron,
gets new relay credentials, so they must be entered again.

Orbit's **Mail** section is not email support. In 0.2.1 the sidebar shows it as
"Coming soon" and upstream's README describes it as in progress with mock data.

## Sign-in

Orbit has no OpenID Connect sign-in
([coollabsio/orbit#65](https://github.com/coollabsio/orbit/issues/65), open on
2026-11-06), so the package has no Cloudron single sign-on. People sign in with
email and password or passkeys; Google and GitHub sign-in can be added in
**Admin → Sign-in providers**.

On first start Orbit prints a one-time setup link in the log. Whoever opens it
first becomes the root user, so it is treated as a password.
`orbit-setup-link` runs `orbit-offline setup-token rotate` for a fresh link.
After setup that command fails by design ("session or token is invalid or
expired"); the wrapper then points to `orbit-offline recovery-link --email`,
which prints a one-time link to set a new password for an account.

## Command-line wrappers

`bin/orbit` runs the upstream CLI as the `cloudron` user with the same
environment as the server (`lib/orbit-env.sh`). Commands that need the SQLite
database to themselves (`root`, `recovery-link`, `setup-token`) run through
`orbit-offline`, which stops the server under supervisord, runs the command and
starts the server again, also when the command fails.

`/app/data/orbit.env` takes only upload limits, job concurrency and rate
limits. Lines are read literally, without shell evaluation; other `ORBIT_*`
names are skipped with a log warning, so a typo cannot stop the app and an
override cannot change paths, origin, proxy trust or the key. Orbit's hosted
mode (`ORBIT_CLOUD`) and billing stay off.

## Local verification

On 2026-11-06 the image was built for `linux/amd64` and run under emulation on
an arm64 Mac, behind a Caddy proxy with an internal TLS certificate, with the
same `CLOUDRON_*` variables Cloudron sets:

- `/health/ready` answered 200 with every check ready; supervisord ran Orbit
  and nginx; Orbit's security headers were present.
- First run: the setup link from the log created the root account and a
  workspace. Tasks, docs and chat worked in the browser.
- Fresh install: the app key was created once and reused across restarts.
  SIGTERM stopped nginx and Orbit cleanly in about 2 seconds.
- Mail through a local SMTP relay that requires authentication, set up from
  `orbit-mail-settings` values with encryption "None (local relay only)": the
  first test email, sent seconds after the relay started, got a 502; the retry
  and later tests were delivered, including after a restart (the stored
  password still decrypted) and after the 0.2.1 upgrade.
- Upgrade: a 0.2.0 data directory started under 0.2.1 healthy, with all
  demo tasks present.
- Database copy: a `.dump` of the 0.2.0 database restored with
  `PRAGMA integrity_check` ok and FTS5 integrity checks passing, and dumped
  identically (156,338 bytes, 77 migrations).
- `orbit-offline root show` and `orbit-offline recovery-link --email` worked;
  `orbit-setup-link` gave a link on a fresh install and failed as expected
  after setup.
- Memory, idle with a small demo workspace and under emulation: Orbit's
  resident memory was about 54 MiB and each container used 104–138 MiB,
  against the 1 GiB limit. Load was not measured.

The browser console showed upstream content security policy reports: an inline
`data:` font blocked on **Admin → Email** in 0.2.1, and in 0.2.0 an inline style
and a 404 for `view-preferences`. Other console errors on some settings pages,
besides the test proxy's untrusted certificate, were not investigated. Pages
rendered and worked.

Not yet checked: an install on a Cloudron server, Cloudron backup and restore,
clone, mail through the Cloudron relay, WebSockets and client addresses through
Cloudron's proxy, connecting an MCP client, and arm64. The checklist is in
[PUBLISHING.md](PUBLISHING.md); record the results here.
