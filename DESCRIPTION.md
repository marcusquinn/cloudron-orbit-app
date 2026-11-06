Orbit is a self-hosted workspace for teams: tasks, docs and chat in one app on
your own server. AI clients connect over MCP and work with the whole workspace
without your data leaving the server.

### Features

* **Tasks:** projects with custom workflows; list, board and timeline views;
  sub-issues, labels, saved views and trash. GitHub sync, and import from
  Asana, Linear and Trello.
* **Docs:** a page tree with live collaborative editing, version history,
  search and Notion import.
* **Chat:** channels, direct messages, threads, files and search.
* **AI:** an MCP server with OAuth. AI clients can read and write tasks and
  docs, and read chat.
* **Admin:** workspaces, members, roles, API tokens, audit log, email, sign-in
  providers, rate limits, storage and workspace export.
* **Sign-in:** email and password or passkeys; Google and GitHub sign-in are
  optional.

Orbit's Mail section is still in development upstream and shows "Coming soon";
it is not a working mail client yet.

### Cloudron integration

* **Backups:** the SQLite database (backed up consistently), attachments and
  the app key are in Cloudron backups.
* **Outgoing mail:** invitations, password resets and sign-up links can go
  through the Cloudron mail relay. Run `orbit-mail-settings` in the Terminal
  for the values to enter in Orbit's Admin → Email page.
* **Command line:** `orbit`, `orbit-offline` and `orbit-setup-link` in the
  Terminal run the upstream operator CLI with this app's settings.

Cloudron single sign-on is not available: Orbit does not support OpenID
Connect yet.

[Orbit](https://github.com/coollabsio/orbit) is open source under the
Apache-2.0 licence. This package is maintained independently of the Orbit
project.
