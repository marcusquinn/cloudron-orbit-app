#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Marcus Quinn
#
# Static package checks: no build, no network. The catalog workflow runs them
# on every PR through package_checks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
	local message="$1"
	printf 'package-test: %s\n' "$message" >&2
	exit 1
}

upstream_version=0.3.0
upstream_commit=a7402204c7cadcac4747cbf47a60685a20f59498
repo_url=https://github.com/marcusquinn/cloudron-orbit-app

# Manifest: port, health, addons and links the runtime depends on.
jq -e --arg v "$upstream_version" --arg c "$upstream_commit" --arg repo "$repo_url" '
	.manifestVersion == 2
	and (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
	and .upstreamVersion == $v
	and .httpPort == 8000
	and .healthCheckPath == "/health/ready"
	and .minBoxVersion == "10.0.0"
	and .memoryLimit == 1073741824
	and (.addons | keys) == ["localstorage", "sendmail"]
	and .addons.localstorage.sqlite.paths == ["/app/data/database/orbit.sqlite"]
	and .upstreamLicense.name == "Apache-2.0"
	and .upstreamLicense.url == "https://github.com/coollabsio/orbit/blob/\($c)/LICENSE"
	and .packagerUrl == "https://github.com/marcusquinn" and .packageUrl == $repo
	and .description == "file://DESCRIPTION.md"
	and .postInstallMessage == "file://POSTINSTALL.md"
	and .changelog == "file://CHANGELOG"
	and .icon == "file://logo.png"
	and (.iconUrl | startswith("https://raw.githubusercontent.com/marcusquinn/cloudron-orbit-app/"))
	and (.mediaLinks | length > 0 and all(startswith("https://raw.githubusercontent.com/marcusquinn/cloudron-orbit-app/")))
' CloudronManifest.json >/dev/null || fail 'CloudronManifest.json does not match the package'

# The image builds the upstream release the manifest names, pinned by digest.
grep -Fxq "ARG ORBIT_VERSION=$upstream_version" Dockerfile || fail 'Dockerfile ORBIT_VERSION'
grep -Fxq "ARG ORBIT_COMMIT=$upstream_commit" Dockerfile || fail 'Dockerfile ORBIT_COMMIT'
grep -Eq "^FROM ghcr\.io/coollabsio/orbit:${upstream_version//./\\.}@sha256:[0-9a-f]{64} AS orbit$" Dockerfile ||
	fail 'upstream image is not the pinned release digest'
grep -Eq '^FROM cloudron/base:[0-9.]+@sha256:[0-9a-f]{64}$' Dockerfile || fail 'base image is not pinned by digest'
grep -Fq "Orbit $upstream_version, commit \`${upstream_commit:0:7}\`" README.md || fail 'README names another upstream release'

# Orbit listens on loopback behind nginx on the manifest port, trusts only
# nginx, and keeps its database where the manifest backs it up.
grep -Fq 'listen 8000 default_server;' nginx.conf.template || fail 'nginx does not listen on httpPort'
grep -Fq 'proxy_set_header X-Forwarded-Proto https;' nginx.conf.template || fail 'nginx does not mark requests as https'
grep -Fxq '	export ORBIT_BIND=127.0.0.1' lib/orbit-env.sh || fail 'Orbit is not bound to loopback'
grep -Fxq '	export ORBIT_TRUSTED_PROXIES=127.0.0.1/32' lib/orbit-env.sh || fail 'Orbit trusts more than nginx'
# The pattern is the literal shell line, so nothing in it may expand.
# shellcheck disable=SC2016
grep -Fxq '	export ORBIT_DATABASE_PATH="$ORBIT_DATA_DIR/database/orbit.sqlite"' lib/orbit-env.sh ||
	fail 'database path differs from the manifest sqlite path'
if grep -Eq '0\.0\.0\.0/0|::/0' lib/orbit-env.sh nginx.conf.template start.sh; then
	fail 'a wildcard proxy range is trusted'
fi
# Operator overrides cannot replace settings the package owns.
grep -Fq 'ORBIT_UPLOAD_MAX_FILE_BYTES | ORBIT_UPLOAD_MAX_REQUEST_BYTES | ORBIT_JOBS_CONCURRENCY | ORBIT_RATE_LIMIT_*)' lib/orbit-env.sh ||
	fail 'override allowlist changed; review README "Settings" too'

# Catalog workflow: the caller binds its helper policy to the reusable pin and
# runs these checks.
workflow=.github/workflows/cloudron-catalog-publish.yml
publisher_ref="$(sed -nE 's|^    uses: marcusquinn/aidevops/\.github/workflows/cloudron-catalog-publish-reusable\.yml@([0-9a-f]{40})$|\1|p' "$workflow")"
test -n "$publisher_ref" || fail 'catalog workflow is not pinned to a full commit'
grep -Fxq "      aidevops_ref: $publisher_ref" "$workflow" || fail 'aidevops_ref differs from the uses pin'
grep -Fxq '        bash test/package-test.sh' "$workflow" || fail 'catalog workflow does not run this test'

# Listing and documentation files.
for file in CHANGELOG DESCRIPTION.md POSTINSTALL.md README.md DESIGN.md logo.png docs/PACKAGING-NOTES.md docs/PUBLISHING.md; do
	test -s "$file" || fail "$file is missing or empty"
done
version="$(jq -r '.version' CloudronManifest.json)"
grep -Fxq "[$version]" CHANGELOG || fail "CHANGELOG has no [$version] entry"
# Only the publication workflow writes catalog entries; never hand-edit them.
jq -e '.versions | type == "object"' CloudronVersions.json >/dev/null || fail 'CloudronVersions.json is malformed'

for script in start.sh lib/orbit-env.sh bin/orbit bin/orbit-offline bin/orbit-setup-link bin/orbit-mail-settings test/package-test.sh; do
	bash -n "$script" || fail "$script has a syntax error"
done
printf 'Package static checks passed\n'
