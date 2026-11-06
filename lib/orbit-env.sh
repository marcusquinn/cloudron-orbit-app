# shellcheck shell=bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Marcus Quinn
#
# The Orbit configuration of this Cloudron app, shared by start.sh and the
# `orbit` CLI wrapper so commands in the Web Terminal see the same settings as
# the running server. Orbit reads its configuration only from ORBIT_*
# variables and refuses to start on one it does not know.

# ORBIT_BIN is used by start.sh and bin/orbit, which source this file.
# shellcheck disable=SC2034
ORBIT_BIN=/app/code/libexec/orbit
ORBIT_DATA_DIR=/app/data
ORBIT_KEY_FILE=/app/data/secrets/app-key
ORBIT_OVERRIDES_FILE=/app/data/orbit.env
# Orbit listens on loopback only; nginx on 8000 is the only way in.
ORBIT_INTERNAL_PORT=8080

# Settings an operator may change in /app/data/orbit.env. Everything else is
# owned by the package (paths, origin, proxy trust, key) or not for
# self-hosting (ORBIT_CLOUD and billing).
orbit_override_allowed() {
	local key="$1"
	case "$key" in
		ORBIT_UPLOAD_MAX_FILE_BYTES | ORBIT_UPLOAD_MAX_REQUEST_BYTES | ORBIT_JOBS_CONCURRENCY | ORBIT_RATE_LIMIT_*)
			return 0
			;;
	esac
	return 1
}

# Reads KEY=VALUE lines literally (no shell evaluation). Disallowed or
# malformed lines are skipped with a warning so a typo cannot stop the app.
orbit_load_overrides() {
	local file="$1"
	local line key value
	[[ -f "$file" ]] || return 0
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%$'\r'}"
		[[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
		if [[ ! "$line" =~ ^(ORBIT_[A-Z0-9_]+)=(.*)$ ]]; then
			printf '%s: ignoring a line that is not ORBIT_NAME=value\n' "$file" >&2
			continue
		fi
		key="${BASH_REMATCH[1]}"
		value="${BASH_REMATCH[2]}"
		if ! orbit_override_allowed "$key"; then
			printf '%s: ignoring %s, which the package manages\n' "$file" "$key" >&2
			continue
		fi
		if [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]]; then
			value="${BASH_REMATCH[1]}"
		fi
		export "$key=$value"
	done <"$file"
	return 0
}

# Exports the server configuration. Mode "server" drops every ORBIT_*
# variable already in the environment. Mode "keep-restore-settings" keeps
# the ORBIT_BACKUP_S3_* variables an operator exports for `orbit backup` on
# a replacement server (upstream docs/operations.md) and drops the rest.
orbit_export_env() {
	local mode="$1"
	case "$mode" in
		server | keep-restore-settings) ;;
		*)
			printf 'orbit_export_env: unknown mode: %s\n' "$mode" >&2
			return 1
			;;
	esac
	local name
	for name in $(compgen -e); do
		case "$name" in
			ORBIT_BACKUP_S3_*)
				[[ "$mode" == keep-restore-settings ]] || unset "$name"
				;;
			ORBIT_*)
				unset "$name"
				;;
		esac
	done

	if [[ -z "${CLOUDRON_APP_ORIGIN:-}" ]]; then
		printf 'CLOUDRON_APP_ORIGIN is not set\n' >&2
		return 1
	fi

	orbit_load_overrides "$ORBIT_OVERRIDES_FILE" || return 1

	export ORBIT_ENV=production
	export ORBIT_BIND=127.0.0.1
	export ORBIT_PORT="$ORBIT_INTERNAL_PORT"
	export ORBIT_PUBLIC_ORIGIN="$CLOUDRON_APP_ORIGIN"
	# Only nginx in this container talks to Orbit; it passes on the client
	# address and https from Cloudron's proxy. See nginx.conf.template.
	export ORBIT_TRUSTED_PROXIES=127.0.0.1/32
	export ORBIT_DATABASE_PATH="$ORBIT_DATA_DIR/database/orbit.sqlite"
	export ORBIT_ATTACHMENTS_PATH="$ORBIT_DATA_DIR/attachments"
	export ORBIT_BACKUPS_PATH="$ORBIT_DATA_DIR/backups"
	export ORBIT_APP_KEY_FILE="$ORBIT_KEY_FILE"
	return 0
}
