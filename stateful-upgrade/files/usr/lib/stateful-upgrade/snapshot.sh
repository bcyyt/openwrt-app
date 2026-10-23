# Collect pre-upgrade snapshot: packages, auth, ssh, custom binaries.

su_copy_if_exists() {
	_src="$1"
	_dst="$2"
	if [ -f "$_src" ] || [ -d "$_src" ]; then
		mkdir -p "$(dirname "$_dst")"
		cp -a "$_src" "$_dst" || return 1
	fi
	return 0
}

snapshot_count_lines() {
	if [ -f "$1" ]; then
		wc -l < "$1" | tr -d ' '
	else
		printf '0'
	fi
}

snapshot_packages() {
	pkg_list_installed > "$SU_SNAP/packages.txt" || return 1
	[ -s "$SU_SNAP/packages.txt" ] || su_log "warning: no installed packages recorded"
	return 0
}

snapshot_auth() {
	_passwd="$(su_live_file /etc/passwd)"
	_shadow="$(su_live_file /etc/shadow)"
	[ -f "$_passwd" ] || return 1
	grep '^root:' "$_passwd" | head -n 1 > "$SU_SNAP/passwd.root" || return 1
	[ -s "$SU_SNAP/passwd.root" ] || return 1
	if [ -f "$_shadow" ]; then
		grep '^root:' "$_shadow" | head -n 1 > "$SU_SNAP/shadow.root" || true
	fi
	return 0
}

snapshot_ssh() {
	mkdir -p "$SU_SNAP/ssh/dropbear" "$SU_SNAP/ssh/root_ssh" "$SU_SNAP/ssh/openssh"
	su_copy_if_exists "$(su_live_file /etc/config/dropbear)" "$SU_SNAP/ssh/dropbear.config"
	if [ -d "$(su_live_file /etc/dropbear)" ]; then
		cp -a "$(su_live_file /etc/dropbear)/." "$SU_SNAP/ssh/dropbear/" 2>/dev/null || true
	fi
	su_copy_if_exists "$(su_live_file /root/.ssh/authorized_keys)" "$SU_SNAP/ssh/root_ssh/authorized_keys"
	su_copy_if_exists "$(su_live_file /etc/config/sshd)" "$SU_SNAP/ssh/sshd.config"
	if [ -d "$(su_live_file /etc/ssh)" ]; then
		cp -a "$(su_live_file /etc/ssh)/." "$SU_SNAP/ssh/openssh/" 2>/dev/null || true
	fi
	return 0
}

snapshot_binaries() {
	_list="$SU_SNAP/binaries.list"
	: > "$_list"
	_ov="$(su_overlay_root)"
	for _rel in bin sbin usr/bin usr/sbin usr/local opt; do
		_dir="$_ov/$_rel"
		[ -d "$_dir" ] || continue
		find "$_dir" -type f 2>/dev/null | while IFS= read -r _f || [ -n "$_f" ]; do
			[ -z "$_f" ] && continue
			[ -x "$_f" ] || continue
			_sys="$(su_rel_path "$_f" "$_ov")"
			_owner="$(pkg_owns "$_sys")"
			[ -n "$_owner" ] && continue
			printf '%s\n' "$_sys"
		done
	done | sort -u > "$_list"

	_tar="$SU_SNAP/binaries.tar.gz"
	if [ ! -s "$_list" ]; then
		rm -f "$_tar"
		return 0
	fi
	_rel_list="$SU_SNAP/binaries.rel"
	sed 's|^/||' "$_list" > "$_rel_list"
	_base="${STATEFUL_ROOT:-/}"
	tar -C "$_base" -czf "$_tar" -T "$_rel_list" || return 1
	return 0
}

snapshot_write_meta() {
	_pc=$(snapshot_count_lines "$SU_SNAP/packages.txt")
	_bc=$(snapshot_count_lines "$SU_SNAP/binaries.list")
	cat > "$SU_SNAP/meta.json" <<EOF
{
  "created_at": "$(su_now)",
  "openwrt_release": "$(su_json_escape "$(su_openwrt_release)")",
  "pkg_mgr": "$(pkg_detect)",
  "status": "pending",
  "plugin_count": ${_pc:-0},
  "binary_count": ${_bc:-0}
}
EOF
}

snapshot_has_ssh() {
	[ -f "$SU_SNAP/ssh/dropbear.config" ] && return 0
	[ -f "$SU_SNAP/ssh/sshd.config" ] && return 0
	[ -f "$SU_SNAP/ssh/root_ssh/authorized_keys" ] && return 0
	if [ -d "$SU_SNAP/ssh/dropbear" ]; then
		find "$SU_SNAP/ssh/dropbear" -type f 2>/dev/null | grep -q . && return 0
	fi
	return 1
}

cmd_preview() {
	_tmp="$(mktemp -d 2>/dev/null || mktemp -d -t suXXXXXX)"
	SU_SNAP="$_tmp"
	mkdir -p "$SU_SNAP/ssh" || su_die "cannot create preview temp dir"
	snapshot_packages || { rm -rf "$_tmp"; su_die "failed to list packages"; }
	snapshot_auth || { rm -rf "$_tmp"; su_die "failed to read root password state"; }
	snapshot_ssh || { rm -rf "$_tmp"; su_die "failed to read SSH settings"; }
	snapshot_binaries || { rm -rf "$_tmp"; su_die "failed to scan custom binaries"; }
	_pc=$(snapshot_count_lines "$SU_SNAP/packages.txt")
	_bc=$(snapshot_count_lines "$SU_SNAP/binaries.list")
	_auth=false
	[ -s "$SU_SNAP/passwd.root" ] && _auth=true
	_ssh=false
	snapshot_has_ssh && _ssh=true
	printf '{\n'
	printf '  "plugin_count": %s,\n' "${_pc:-0}"
	printf '  "binary_count": %s,\n' "${_bc:-0}"
	printf '  "auth": %s,\n' "$_auth"
	printf '  "ssh": %s,\n' "$_ssh"
	printf '  "pkg_mgr": "%s",\n' "$(pkg_detect)"
	printf '  "plugins": ['
	awk -F '\t' 'NF{printf "%s{\"name\":\"%s\",\"version\":\"%s\"}", (n++?",":""), $1, $2}' "$SU_SNAP/packages.txt" 2>/dev/null
	printf '],\n  "binaries": '
	su_json_string_array_file "$SU_SNAP/binaries.list"
	printf '\n}\n'
	rm -rf "$_tmp"
}

cmd_snapshot() {
	su_ensure_data || su_die "cannot create snapshot directory"
	rm -rf "$SU_SNAP"
	mkdir -p "$SU_SNAP" "$SU_PROGRESS" || su_die "cannot create snapshot directory"
	snapshot_packages || su_die "failed to record installed plugins"
	snapshot_auth || su_die "failed to record root password state"
	snapshot_ssh || su_die "failed to record SSH settings"
	snapshot_binaries || su_die "failed to record custom binaries"
	snapshot_write_meta || su_die "failed to write snapshot metadata"
	: > "$SU_SNAP/PENDING"
	rm -f "$SU_SNAP/CONSUMED"
	su_set_status pending
	su_log "snapshot written to $SU_SNAP"
}
