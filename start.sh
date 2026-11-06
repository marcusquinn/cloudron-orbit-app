#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Marcus Quinn
#
# Prepares /app/data and /run, then hands over to supervisord, which runs
# Orbit (as cloudron, on 127.0.0.1:8080) and nginx (on 8000, Cloudron's
# httpPort).
set -euo pipefail
umask 077

# shellcheck source=lib/orbit-env.sh
source /app/code/lib/orbit-env.sh

# Cloudron's reverse proxy and health checker connect from the container's
# default gateway on the Cloudron Docker network. nginx trusts the
# X-Forwarded-For header only from that address.
detect_cloudron_proxy() {
	local destination gateway
	while read -r _ destination gateway _; do
		if [[ "$destination" == 00000000 && "$gateway" =~ ^[0-9A-Fa-f]{8}$ && "$gateway" != 00000000 ]]; then
			# /proc/net/route stores the IPv4 address as little-endian hex.
			printf '%d.%d.%d.%d\n' "0x${gateway:6:2}" "0x${gateway:4:2}" "0x${gateway:2:2}" "0x${gateway:0:2}"
			return 0
		fi
	done </proc/net/route
	return 1
}

ensure_app_key() {
	local key_file="$1"
	local key
	if [[ ! -s "$key_file" ]]; then
		openssl rand -base64 32 >"$key_file.tmp"
		mv "$key_file.tmp" "$key_file"
		printf 'Created the Orbit app key in %s; keep a copy outside this server\n' "$key_file"
	fi
	key="$(<"$key_file")"
	if [[ ! "$key" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
		printf '%s does not hold base64 of 32 bytes; restore the original key file\n' "$key_file" >&2
		return 1
	fi
	return 0
}

seed_overrides_file() {
	local file="$1"
	[[ -f "$file" ]] && return 0
	cat >"$file.tmp" <<'EOF'
# Orbit settings for this app, one ORBIT_NAME=value per line; restart the app
# after a change. Only these may be set here (the package manages the rest):
#   ORBIT_UPLOAD_MAX_FILE_BYTES     largest file, default 26214400 (25 MiB)
#   ORBIT_UPLOAD_MAX_REQUEST_BYTES  largest upload request
#   ORBIT_JOBS_CONCURRENCY          background jobs at once, default 4
#   ORBIT_RATE_LIMIT_*              rate limits, see upstream docs/operations.md
#
# ORBIT_UPLOAD_MAX_FILE_BYTES=104857600
EOF
	mv "$file.tmp" "$file"
	return 0
}

mkdir -p \
	"$ORBIT_DATA_DIR/database" \
	"$ORBIT_DATA_DIR/attachments" \
	"$ORBIT_DATA_DIR/backups" \
	"$ORBIT_DATA_DIR/secrets" \
	/run/orbit \
	/run/nginx/client-body /run/nginx/proxy /run/nginx/fastcgi /run/nginx/scgi /run/nginx/uwsgi \
	/run/supervisor

ensure_app_key "$ORBIT_KEY_FILE"
seed_overrides_file "$ORBIT_OVERRIDES_FILE"
orbit_export_env

proxy_address="$(detect_cloudron_proxy || true)"
if [[ ! "$proxy_address" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
	proxy_address=172.18.0.1
	printf 'Could not read the default gateway; trusting X-Forwarded-For from %s\n' "$proxy_address" >&2
fi
sed -e "s|@CLOUDRON_PROXY@|$proxy_address|g" -e "s|@ORBIT_PORT@|$ORBIT_INTERNAL_PORT|g" \
	/app/code/nginx.conf.template >/run/orbit/nginx.conf

chown -R cloudron:cloudron "$ORBIT_DATA_DIR" /run/nginx
chmod 0700 "$ORBIT_DATA_DIR/secrets"
chmod 0600 "$ORBIT_KEY_FILE"

printf 'Orbit %s (upstream commit %s)\n' "$(</app/code/upstream-version)" "$(</app/code/upstream-commit)"
gosu cloudron:cloudron "$ORBIT_BIN" config check

exec /usr/bin/supervisord --configuration /app/code/supervisord.conf --nodaemon
