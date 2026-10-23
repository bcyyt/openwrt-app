#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"
setup_root

out="$(run_su preview)"
echo "$out" | grep -q '"plugin_count": 3'
echo "$out" | grep -q '"auth": true'
echo "$out" | grep -q '"ssh": true'
echo "$out" | grep -q 'luci-app-acme'
echo "$out" | grep -q '/usr/bin/mytool'
echo "$out" | grep -v -q 'opkg-owned' || {
	# owned binary must not appear in binaries array as a custom file
	echo "$out" | grep '"binaries"' -A2 | grep -q opkg-owned && {
		echo "owned binary leaked into preview" >&2
		exit 1
	}
}

run_su snapshot
assert_eq "$(run_su status)" "pending" "status after snapshot"
assert_file "$TEST_ROOT/etc/stateful-upgrade/snapshot/packages.txt" "packages"
assert_contains "$TEST_ROOT/etc/stateful-upgrade/snapshot/packages.txt" "luci-app-acme" "acme recorded"
assert_contains "$TEST_ROOT/etc/stateful-upgrade/snapshot/passwd.root" "root:" "passwd root"
assert_file "$TEST_ROOT/etc/stateful-upgrade/snapshot/ssh/dropbear.config" "dropbear config"
assert_contains "$TEST_ROOT/etc/stateful-upgrade/snapshot/binaries.list" "/usr/bin/mytool" "custom binary"
assert_not_contains "$TEST_ROOT/etc/stateful-upgrade/snapshot/binaries.list" "opkg-owned" "skip packaged binary"

echo "OK preview_snapshot"
