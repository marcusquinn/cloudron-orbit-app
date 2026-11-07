# Publish and qualify the Cloudron package

## Release authority

Pull requests run the static package checks and ShellCheck and build the image
without pushing it. Merging is not authorization to publish. The catalog
workflow also runs on main but does not publish until the operator sets the
repository variable `CLOUDRON_PUBLICATION_ENABLED=true`. Setting it is standing
authorization for that workflow to publish images and catalog entries from
main. Leave it unset until the test install below has passed.

The workflow pushes the catalog commit and tag with its job token. main has no
branch protection or rules today. If rules are added that require pull
requests or status checks, add a repository secret `CLOUDRON_RELEASE_PAT` with
only the permission needed to push to this repository. Never put it in Git or
an issue. GHCR image pushes always use the job token.

## Pipeline

1. In a PR, update the manifest `version`, the `CHANGELOG` `[X.Y.Z]` entry and,
   for a new upstream release, every upstream pin: the Dockerfile's
   `ORBIT_VERSION`, `ORBIT_COMMIT` and image digest, the manifest's
   `upstreamVersion` and license URL, the README table, and
   `test/package-test.sh`, which checks they agree.
2. Build, run the checklist below as far as the change needs, review and merge.
3. Once publication is enabled, the workflow builds the merged source for
   `linux/amd64`, pushes `ghcr.io/marcusquinn/cloudron-orbit-app`, and attests
   the image digest with GitHub keyless provenance.
4. After the first push, make the GHCR package public. The workflow checks that
   the digest can be pulled anonymously before it publishes a catalog entry; if
   the package is still private, change its visibility and rerun the job.
5. The Cloudron CLI (9.0.3, checked against a reviewed npm integrity hash)
   adds the version to `CloudronVersions.json` as testing, then changes it to
   published. Never edit the catalog by hand.
6. The workflow attests the catalog, commits only that file, and pushes main and
   the `vX.Y.Z` tag together. If main moved meanwhile, the push is rejected
   rather than overwriting; rerun from the new main.
7. Its release job creates the GitHub release for the tag after checking that
   the tag is on main, the catalog's image digest pulls anonymously, and the
   catalog and image carry this workflow's provenance. The release notes are
   the version's `CHANGELOG` entries; an empty entry fails the job. Published
   versions are never rebuilt or overwritten: roll back by publishing a new
   version.
8. Update the installs that follow the catalog and check them (see below).

If a step fails after the image push, no catalog entry exists for that version.
A pushed image without one is not installable; fix the cause and rerun from the
same main. Never force-push publication history.

The catalog commit's message carries GitHub's skip-CI marker so that it does not
start another publication run; that also skips tag-push workflows such as
`cloudron-package-release.yml` for its tag. GitHub skips push and pull request
runs when the head commit message contains the marker anywhere, so describe it
in prose in commit messages, PR descriptions and squash bodies; a merge whose
message quotes it would skip the run that publishes or repairs the release.

Verify provenance with
`gh attestation verify oci://<image@digest> --repo marcusquinn/cloudron-orbit-app`
and, for a downloaded catalog,
`gh attestation verify CloudronVersions.json --repo marcusquinn/cloudron-orbit-app`.

## Store listing

The catalog URL is
`https://raw.githubusercontent.com/marcusquinn/cloudron-orbit-app/main/CloudronVersions.json`.
The CLI copies the manifest into each catalog entry, so a listing shows
`DESCRIPTION.md`, `POSTINSTALL.md`, that version's `CHANGELOG` entry, the icon
and the `mediaLinks` as they were when it was published. Keep `iconUrl` and
`mediaLinks` pinned to a commit so published entries never change;
[DESIGN.md](../DESIGN.md) records how the images were made and reviewed. Before
a release, check that each URL returns HTTPS 200 with an image content type.

To list the app on [Community Apps](https://ca.cloudron.io), sign in, add the
catalog URL to your apps, and check the imported title, icon, screenshots,
changelog and install link. Announce new packages in the forum's
[Community Apps](https://forum.cloudron.io/category/220/community-apps)
category. Orbit's Mail section is not email support yet; say so in the
announcement.

## Test install checklist

Use a disposable location such as **orbit-test**, never a production app.
Before the package is published, `cloudron install --location orbit-test` from
a checkout builds the image on the server, so no registry is needed;
`cloudron update --app orbit-test` rebuilds after changes.

- TLS and `/health/ready`; the setup link in the log; `orbit-setup-link`;
  creating the root account and a workspace.
- Client addresses: wherever Orbit shows a client address, such as the audit
  log, it is the browser's, not the proxy's.
- WebSockets through Cloudron's proxy: a chat message and a doc edit appear
  live in a second browser, and stay connected for some minutes.
- Uploads: a file under 25 MiB attaches; a larger one is refused and nothing
  is stored. Chat shows "Upload failed."; the response is 413 or 502 (see
  [PACKAGING-NOTES.md](PACKAGING-NOTES.md)).
- Mail through the Cloudron relay with `orbit-mail-settings`: test email,
  an emailed invitation and a password reset.
- An MCP client (for example Claude Code) connects over OAuth.
- Restart: sessions, settings and the stored SMTP password survive.
- Backup, then restore into a clone: data and attachments are present, the
  stored secrets still decrypt, and the clone's mail works after entering its
  own `orbit-mail-settings` values.
- Update from the previous build: migrations run and Orbit's pre-migration
  snapshot is in `/app/data/backups`.
- Memory at idle and while several people use it, against the 1 GiB limit.

Record the Cloudron version, image digest and results in
[PACKAGING-NOTES.md](PACKAGING-NOTES.md).
