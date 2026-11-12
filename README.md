# Orbit for Cloudron

A [Cloudron](https://cloudron.io) package for
[Orbit](https://github.com/coollabsio/orbit): self-hosted tasks, docs and team
chat in one workspace, with an MCP server for AI clients.

| | |
|---|---|
| Upstream | Orbit 0.3.0, commit `a740220`, Apache-2.0 |
| Package | 0.1.1, MIT |
| Status | Testing release. Orbit 0.2.1 was checked on one Cloudron 10.1.6 server; 0.3.0 has not been ([results](docs/PACKAGING-NOTES.md#cloudron-verification)) |
| Requires | Cloudron 10.0.0 or later, x86-64 |
| Install | `cloudron install --versions-url https://raw.githubusercontent.com/marcusquinn/cloudron-orbit-app/main/CloudronVersions.json` |

Orbit is early-stage software. Its Mail section is a preview with mock data
upstream ("Coming soon" in the sidebar) and is not a working mail client yet.

## How the package works

The image copies the `orbit` binary from upstream's release image
(`ghcr.io/coollabsio/orbit`, pinned by digest) onto the Cloudron base image.
supervisord runs two processes:

- **Orbit** as the `cloudron` user on `127.0.0.1:8080`, with SQLite storage.
- **nginx** on port 8000, Cloudron's `httpPort`. It forwards to Orbit with
  `X-Forwarded-Proto: https` and the client address, streams uploads and keeps
  WebSockets open for up to an hour.

Orbit runs in production mode, which refuses plain HTTP and requires the public
origin, an app key and a trusted proxy list. `start.sh` sets these from
Cloudron: the origin is `CLOUDRON_APP_ORIGIN`, the only trusted proxy is nginx
on loopback, and nginx accepts `X-Forwarded-For` only from the container's
default gateway (Cloudron's proxy). Orbit's hosted-service mode
(`ORBIT_CLOUD`) is off.

## First run

1. Open the app's **Logs** and the one-time setup link Orbit printed, or run
   `orbit-setup-link` in the **Terminal** for a fresh one. Create the root
   account and the first workspace.
2. In **Admin → Email**, enter the values from `orbit-mail-settings`, choose
   **None (local relay only)** and send a test email. Orbit keeps SMTP settings
   in its database, so the package cannot fill them in for you
   ([upstream #66](https://github.com/coollabsio/orbit/issues/66)).
3. Invite people from **Settings → Members**: send the invitation by email or
   use **Generate link**.

Google and GitHub sign-in are optional, in **Admin → Sign-in providers**.
Cloudron single sign-on needs OpenID Connect support upstream
([#65](https://github.com/coollabsio/orbit/issues/65)).

## Data and backups

Everything is in `/app/data`, which Cloudron backs up:

| Path | Contents |
|---|---|
| `database/orbit.sqlite` | The database, in WAL mode. Declared as a Cloudron SQLite path, so backups take a consistent copy. |
| `attachments/` | Uploaded files, unless **Admin → Storage** moves them to S3. |
| `backups/` | Orbit's own snapshots, such as the copy taken before a migration. |
| `secrets/app-key` | The key that encrypts stored SMTP and sign-in provider secrets. Without it those secrets cannot be read. |
| `orbit.env` | Optional settings, see below. |

Restore through Cloudron's backup and restore. Orbit's own S3 backups in
**Admin → Backups** are optional. Files moved to S3 storage are no longer in
Cloudron backups.

## Settings

`/app/data/orbit.env` takes `ORBIT_NAME=value` lines; restart the app after a
change. Only these settings are accepted; the package sets the rest and skips
others with a warning in the log:

- `ORBIT_UPLOAD_MAX_FILE_BYTES`: largest upload, default 25 MiB. Chat shows
  only "Upload failed." for a larger file.
- `ORBIT_UPLOAD_MAX_REQUEST_BYTES`: largest upload request.
- `ORBIT_JOBS_CONCURRENCY`: background jobs at once, default 4.
- `ORBIT_RATE_LIMIT_*`: rate limits, see upstream
  [docs/operations.md](https://github.com/coollabsio/orbit/blob/a7402204c7cadcac4747cbf47a60685a20f59498/docs/operations.md).

Everything else, including email and sign-in providers, is set in Orbit's
**Admin** pages.

## Terminal commands

| Command | Use |
|---|---|
| `orbit <command>` | The upstream CLI with this app's settings, run as the `cloudron` user. `orbit config check` and `orbit config show` work while Orbit runs. |
| `orbit-offline <command>` | Stops Orbit for a few seconds, runs `orbit <command>`, then starts it again. For commands that need the database to themselves, such as `recovery-link --email EMAIL` (a one-time account recovery link, when email is not set up) and `root show`. |
| `orbit-setup-link` | A fresh first-run setup link. |
| `orbit-mail-settings` | The Cloudron mail relay values for **Admin → Email**. Prints the relay password. |

## Build and test

```bash
cloudron build              # or: docker build --platform linux/amd64 .
cloudron install --location orbit-test
bash test/package-test.sh   # static package checks
```

`cloudron install` from a checkout builds the image on the server, so no
registry is needed for a test install. Publishing is described in
[docs/PUBLISHING.md](docs/PUBLISHING.md); packaging decisions and test results
are in [docs/PACKAGING-NOTES.md](docs/PACKAGING-NOTES.md).

## License

The package is MIT-licensed ([LICENSE](LICENSE)). Orbit is Apache-2.0 and
belongs to its authors; the icon is Orbit's logo from the upstream repository.
This package is maintained independently of the Orbit project.
