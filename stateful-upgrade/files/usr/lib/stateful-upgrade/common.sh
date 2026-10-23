# Shared helpers for stateful-upgrade. POSIX / ash.

STATEFUL_ROOT="${STATEFUL_ROOT:-}"

su_path() {
	printf '%s%s' "${STATEFUL_ROOT}" "$1"
}

SU_DATA="$(su_path /etc/stateful-upgrade)"
SU_SNAP="$SU_DATA/snapshot"
SU_PROGRESS="$SU_DATA/progress"
SU_STATUS="$SU_DATA/status"
SU_REPORT="$SU_DATA/report.json"
SU_LOG="$SU_DATA/restore.log"

su_log() {
	printf '%s %s\n' "$(su_now)" "$*" >&2
	if [ -d "$SU_DATA" ]; then
		printf '%s %s\n' "$(su_now)" "$*" >> "$SU_LOG" 2>/dev/null || true
	fi
}

su_die() {
	su_log "error: $*"
	printf '%s\n' "$*" >&2
	exit 1
}

su_now() {
	date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date
}

su_openwrt_release() {
	if [ -f "$(su_path /etc/openwrt_release)" ]; then
		# shellcheck disable=SC1091
		. "$(su_path /etc/openwrt_release)"
		printf '%s' "${DISTRIB_RELEASE:-unknown}"
	else
		printf '%s' "unknown"
	fi
}

su_ensure_data() {
	mkdir -p "$SU_SNAP" "$SU_PROGRESS" "$(su_path /tmp/stateful-upgrade)" || return 1
}

su_set_status() {
	su_ensure_data || return 1
	printf '%s\n' "$1" > "$SU_STATUS"
}

su_get_status() {
	if [ -f "$SU_STATUS" ]; then
		head -n 1 "$SU_STATUS"
	else
		printf '%s\n' "idle"
	fi
}

su_json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

su_json_string_array_file() {
	_first=1
	printf '['
	if [ -f "$1" ]; then
		while IFS= read -r _line || [ -n "$_line" ]; do
			[ -z "$_line" ] && continue
			if [ "$_first" -eq 1 ]; then
				_first=0
			else
				printf ','
			fi
			printf '"%s"' "$(su_json_escape "$_line")"
		done < "$1"
	fi
	printf ']'
}

su_progress_done() {
	[ -f "$SU_PROGRESS/$1" ]
}

su_progress_mark() {
	mkdir -p "$SU_PROGRESS" || return 1
	printf '1\n' > "$SU_PROGRESS/$1"
}

su_overlay_root() {
	if [ -n "${STATEFUL_OVERLAY:-}" ]; then
		printf '%s' "$STATEFUL_OVERLAY"
	elif [ -d "$(su_path /overlay/upper)" ]; then
		printf '%s' "$(su_path /overlay/upper)"
	else
		printf '%s' "${STATEFUL_ROOT:-/}"
	fi
}

su_rel_path() {
	# Map overlay-absolute path to device path starting with /
	_abs="$1"
	_ov="$2"
	case "$_abs" in
	"$_ov"/*)
		printf '/%s' "${_abs#$_ov/}"
		;;
	*)
		# Strip STATEFUL_ROOT if present
		if [ -n "$STATEFUL_ROOT" ]; then
			case "$_abs" in
			"$STATEFUL_ROOT"/*)
				printf '%s' "${_abs#$STATEFUL_ROOT}"
				return 0
				;;
			esac
		fi
		printf '%s' "$_abs"
		;;
	esac
}

su_live_file() {
	# device path /etc/foo -> prefixed path
	printf '%s' "$(su_path "$1")"
}
