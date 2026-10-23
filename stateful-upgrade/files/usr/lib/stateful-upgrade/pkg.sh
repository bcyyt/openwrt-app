# opkg / apk adapter and Essential package protection.

ESSENTIAL_PACKAGES="
base-files busybox fstools procd ubusd ubus ubox uci cgi-io
uhttpd uhttpd-mod-ubus rpcd rpcd-mod-file rpcd-mod-luci rpcd-mod-rrdns
luci luci-base luci-mod-system luci-mod-status luci-mod-network
luci-mod-admin-full luci-theme-bootstrap luci-app-firewall luci-compat
netifd jsonfilter libubus libubox libuci dropbear openssh-server openssh-client
firewall firewall4 nftables dnsmasq odhcpd odhcpd-ipv6only odhcp6c
ppp ppp-mod-pppoe logd urngd kernel libc libgcc musl
"

pkg_detect() {
	if command -v apk >/dev/null 2>&1 && [ -d "$(su_path /etc/apk)" ]; then
		printf '%s' "apk"
	else
		printf '%s' "opkg"
	fi
}

pkg_list_installed() {
	# name<TAB>version
	if [ "$(pkg_detect)" = "apk" ]; then
		if command -v apk >/dev/null 2>&1; then
			apk info 2>/dev/null | while IFS= read -r _n || [ -n "$_n" ]; do
				[ -z "$_n" ] && continue
				_v=$(apk info -d "$_n" 2>/dev/null | sed -n '1s/.*-\([0-9].*\)/\1/p' | head -n 1)
				[ -z "$_v" ] && _v="-"
				printf '%s\t%s\n' "$_n" "$_v"
			done
		fi
	else
		opkg list-installed 2>/dev/null | sed 's/ - /\t/'
	fi
}

pkg_is_installed() {
	_want="$1"
	pkg_list_installed | awk -F '\t' -v n="$_want" '$1==n { found=1 } END { exit found ? 0 : 1 }'
}

pkg_install() {
	_pkg="$1"
	if [ "$(pkg_detect)" = "apk" ]; then
		apk add "$_pkg"
	else
		opkg install "$_pkg"
	fi
}

pkg_remove() {
	_pkg="$1"
	if [ "$(pkg_detect)" = "apk" ]; then
		apk del "$_pkg"
	else
		opkg remove "$_pkg"
	fi
}

pkg_update() {
	if [ "$(pkg_detect)" = "apk" ]; then
		apk update
	else
		opkg update
	fi
}

pkg_owns() {
	_path="$1"
	if [ "$(pkg_detect)" = "apk" ]; then
		apk info --who-owns "$_path" 2>/dev/null | awk '{print $1; exit}'
		return 0
	fi
	_info="$(su_path /usr/lib/opkg/info)"
	if [ -d "$_info" ]; then
		grep -l "^${_path}\$" "$_info"/*.list 2>/dev/null | sed 's|.*/||; s/\.list$//' | head -n 1
	fi
}

pkg_status_text() {
	_pkg="$1"
	if [ "$(pkg_detect)" = "apk" ]; then
		apk info -a "$_pkg" 2>/dev/null
	else
		opkg status "$_pkg" 2>/dev/null
	fi
}

pkg_is_flagged_essential() {
	_pkg="$1"
	pkg_status_text "$_pkg" | grep -q '^Essential: yes'
}

pkg_direct_depends() {
	_pkg="$1"
	if [ "$(pkg_detect)" = "apk" ]; then
		apk info -R "$_pkg" 2>/dev/null | awk 'NF && $1 !~ /:/ {print $1}'
		return 0
	fi
	opkg status "$_pkg" 2>/dev/null | sed -n 's/^Depends: //p' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]].*//; s/(.*//; /^$/d'
}

pkg_is_essential() {
	_pkg="$1"
	[ -n "$_pkg" ] || return 1
	for _e in $ESSENTIAL_PACKAGES; do
		[ "$_pkg" = "$_e" ] && return 0
	done
	pkg_is_flagged_essential "$_pkg" && return 0
	# Direct dependency of a currently installed essential package.
	for _e in $ESSENTIAL_PACKAGES; do
		pkg_is_installed "$_e" || continue
		pkg_direct_depends "$_e" | awk -v n="$_pkg" '$1==n { found=1 } END { exit found ? 0 : 1 }' && return 0
	done
	return 1
}
