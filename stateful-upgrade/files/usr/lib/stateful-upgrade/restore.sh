# Post-sysupgrade restore. Auth/SSH/binaries/remove run once; install retries.

replace_account_line() {
	_file="$1"
	_line="$2"
	[ -n "$_line" ] || return 0
	[ -f "$_file" ] || return 1
	_tmp="$_file.stateful-upgrade.new"
	awk -v line="$_line" '
		BEGIN { FS=":" }
		$1=="root" { print line; replaced=1; next }
		{ print }
		END { if (!replaced) print line }
	' "$_file" > "$_tmp" || return 1
	mv "$_tmp" "$_file"
}

restore_auth() {
	su_progress_done auth && return 0
	_ok=1
	if [ -s "$SU_SNAP/passwd.root" ]; then
		replace_account_line "$(su_live_file /etc/passwd)" "$(head -n 1 "$SU_SNAP/passwd.root")" || _ok=0
	else
		_ok=0
	fi
	if [ -s "$SU_SNAP/shadow.root" ]; then
		replace_account_line "$(su_live_file /etc/shadow)" "$(head -n 1 "$SU_SNAP/shadow.root")" || _ok=0
	fi
	if [ "$_ok" -eq 1 ]; then
		printf 'true\n' > "$SU_DATA/auth_restored"
		su_progress_mark auth
		return 0
	fi
	printf 'false\n' > "$SU_DATA/auth_restored"
	su_log "root password restore failed"
	return 1
}

ssh_restart() {
	_svc="$(su_live_file /etc/init.d/dropbear)"
	if [ -x "$_svc" ]; then
		"$_svc" restart
		return $?
	fi
	_svc="$(su_live_file /etc/init.d/sshd)"
	if [ -x "$_svc" ]; then
		"$_svc" restart
		return $?
	fi
	return 0
}

ssh_rollback() {
	_rom="$(su_path /rom)"
	if [ -f "$_rom/etc/config/dropbear" ]; then
		cp -a "$_rom/etc/config/dropbear" "$(su_live_file /etc/config/dropbear)" || true
	fi
	if [ -d "$_rom/etc/dropbear" ]; then
		mkdir -p "$(su_live_file /etc/dropbear)"
		cp -a "$_rom/etc/dropbear/." "$(su_live_file /etc/dropbear)/" || true
	fi
	ssh_restart || true
}

restore_ssh() {
	su_progress_done ssh && return 0
	mkdir -p "$(su_live_file /etc/config)" "$(su_live_file /etc/dropbear)" "$(su_live_file /root/.ssh)"
	[ -f "$SU_SNAP/ssh/dropbear.config" ] && cp -a "$SU_SNAP/ssh/dropbear.config" "$(su_live_file /etc/config/dropbear)"
	if [ -d "$SU_SNAP/ssh/dropbear" ]; then
		cp -a "$SU_SNAP/ssh/dropbear/." "$(su_live_file /etc/dropbear)/" 2>/dev/null || true
	fi
	[ -f "$SU_SNAP/ssh/root_ssh/authorized_keys" ] && cp -a "$SU_SNAP/ssh/root_ssh/authorized_keys" "$(su_live_file /root/.ssh/authorized_keys)"
	[ -f "$SU_SNAP/ssh/sshd.config" ] && cp -a "$SU_SNAP/ssh/sshd.config" "$(su_live_file /etc/config/sshd)"
	if [ -d "$SU_SNAP/ssh/openssh" ]; then
		mkdir -p "$(su_live_file /etc/ssh)"
		cp -a "$SU_SNAP/ssh/openssh/." "$(su_live_file /etc/ssh)/" 2>/dev/null || true
	fi
	if ssh_restart; then
		printf 'true\n' > "$SU_DATA/ssh_restored"
		su_progress_mark ssh
		return 0
	fi
	su_log "SSH restart failed, rolling back to firmware default SSH config"
	ssh_rollback
	printf 'false\n' > "$SU_DATA/ssh_restored"
	su_progress_mark ssh
	return 0
}

restore_binaries() {
	su_progress_done binaries && return 0
	: > "$SU_DATA/binaries_restored.txt"
	if [ -f "$SU_SNAP/binaries.tar.gz" ] && [ -s "$SU_SNAP/binaries.list" ]; then
		_base="${STATEFUL_ROOT:-/}"
		tar -C "$_base" -xzf "$SU_SNAP/binaries.tar.gz" || su_log "binary tar extract reported errors"
		while IFS= read -r _p || [ -n "$_p" ]; do
			[ -z "$_p" ] && continue
			if [ -e "$(su_live_file "$_p")" ]; then
				printf '%s\n' "$_p" >> "$SU_DATA/binaries_restored.txt"
			else
				printf '%s\t%s\t%s\n' "$_p" "binary" "restore failed" >> "$SU_DATA/failed.txt"
			fi
		done < "$SU_SNAP/binaries.list"
	fi
	su_progress_mark binaries
	return 0
}

restore_remove() {
	su_progress_done remove && return 0
	: > "$SU_DATA/removed.txt"
	: > "$SU_DATA/skipped_essential.txt"
	pkg_list_installed | while IFS="$(printf '\t')" read -r _name _ver || [ -n "$_name" ]; do
		[ -z "$_name" ] && continue
		if awk -F '\t' -v n="$_name" '$1==n { found=1 } END { exit found ? 0 : 1 }' "$SU_SNAP/packages.txt"; then
			continue
		fi
		if pkg_is_essential "$_name"; then
			printf '%s\n' "$_name" >> "$SU_DATA/skipped_essential.txt"
			continue
		fi
		if pkg_remove "$_name"; then
			printf '%s\n' "$_name" >> "$SU_DATA/removed.txt"
		else
			printf '%s\t%s\t%s\n' "$_name" "remove" "remove failed" >> "$SU_DATA/failed.txt"
		fi
	done
	su_progress_mark remove
	return 0
}

wait_for_network() {
	[ "${STATEFUL_SKIP_NET:-0}" = "1" ] && return 0
	_i=0
	while [ "$_i" -lt 60 ]; do
		if ping -c 1 -W 1 223.5.5.5 >/dev/null 2>&1 || ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
			return 0
		fi
		_i=$((_i + 1))
		sleep 1
	done
	return 1
}

restore_install() {
	: > "$SU_DATA/install_pending.txt"
	[ -f "$SU_DATA/installed.txt" ] || : > "$SU_DATA/installed.txt"
	wait_for_network || su_log "network not ready, package update may fail"
	pkg_update || su_log "package index update failed"
	while IFS="$(printf '\t')" read -r _name _ver || [ -n "$_name" ]; do
		[ -z "$_name" ] && continue
		if pkg_is_installed "$_name"; then
			continue
		fi
		if pkg_install "$_name"; then
			printf '%s\n' "$_name" >> "$SU_DATA/installed.txt"
		else
			printf '%s\n' "$_name" >> "$SU_DATA/install_pending.txt"
			printf '%s\t%s\t%s\n' "$_name" "install" "install failed" >> "$SU_DATA/failed.txt"
		fi
	done < "$SU_SNAP/packages.txt"
}

write_report() {
	_auth=false
	_ssh=false
	[ "$(cat "$SU_DATA/auth_restored" 2>/dev/null)" = "true" ] && _auth=true
	[ "$(cat "$SU_DATA/ssh_restored" 2>/dev/null)" = "true" ] && _ssh=true
	_failed_json="[]"
	if [ -f "$SU_DATA/failed.txt" ]; then
		_failed_json=$(awk -F '\t' 'NF>=3{
			printf "%s{\"name\":\"%s\",\"action\":\"%s\",\"error\":\"%s\"}", (n++?",":""), $1, $2, $3
		}' "$SU_DATA/failed.txt")
		_failed_json="[${_failed_json}]"
	fi
	cat > "$SU_REPORT" <<EOF
{
  "finished_at": "$(su_now)",
  "installed": $(su_json_string_array_file "$SU_DATA/installed.txt"),
  "removed": $(su_json_string_array_file "$SU_DATA/removed.txt"),
  "skipped_essential": $(su_json_string_array_file "$SU_DATA/skipped_essential.txt"),
  "failed": ${_failed_json},
  "binaries_restored": $(su_json_string_array_file "$SU_DATA/binaries_restored.txt"),
  "auth_restored": ${_auth},
  "ssh_restored": ${_ssh},
  "install_pending": $(su_json_string_array_file "$SU_DATA/install_pending.txt")
}
EOF
}

cmd_restore() {
	if [ -f "$SU_SNAP/CONSUMED" ]; then
		su_set_status completed
		return 0
	fi
	if [ ! -f "$SU_SNAP/packages.txt" ]; then
		if [ -f "$SU_SNAP/PENDING" ]; then
			su_set_status failed
			su_die "snapshot is incomplete"
		fi
		su_set_status idle
		return 0
	fi
	su_ensure_data || su_die "cannot create data directory"
	: > "$SU_DATA/failed.txt"
	su_set_status restoring
	restore_auth || true
	restore_ssh || true
	restore_binaries || true
	restore_remove || true
	restore_install || true
	write_report
	if [ -s "$SU_DATA/install_pending.txt" ]; then
		su_set_status restoring
		su_log "install still pending, will retry on next boot"
		return 0
	fi
	rm -f "$SU_SNAP/PENDING"
	: > "$SU_SNAP/CONSUMED"
	su_set_status completed
	su_log "restore completed"
}

cmd_status() {
	su_get_status
}

cmd_report() {
	if [ -f "$SU_REPORT" ]; then
		cat "$SU_REPORT"
	else
		printf '{}\n'
	fi
}
