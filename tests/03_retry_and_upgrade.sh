#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"
setup_root

run_su snapshot
printf 'luci-base - 1.0\nbusybox - 1.36\n' > "$TEST_ROOT/var/opkg/installed"
printf '1\n' > "$TEST_ROOT/var/opkg/fail_install"

run_su restore
assert_eq "$(run_su status)" "restoring" "stay restoring when install fails"
assert_file "$TEST_ROOT/etc/stateful-upgrade/progress/auth" "auth done once"
assert_not_contains "$TEST_ROOT/var/opkg/installed" "luci-app-acme" "acme not installed yet"

printf '' > "$TEST_ROOT/var/opkg/fail_install"
run_su restore
assert_eq "$(run_su status)" "completed" "completed after retry"
assert_contains "$TEST_ROOT/var/opkg/installed" "luci-app-acme" "acme installed on retry"

setup_root
printf 'FAILTEST\n' > "$TEST_ROOT/fw.bin"
if run_su upgrade "$TEST_ROOT/fw.bin"; then
	echo "upgrade should fail --test" >&2
	exit 1
fi
if [ -f "$TEST_ROOT/sysupgrade.image" ]; then
	echo "sysupgrade should not run after --test fail" >&2
	exit 1
fi

printf 'FAILTEST\n' > "$TEST_ROOT/fw.bin"
run_su upgrade "$TEST_ROOT/fw.bin" --force
assert_file "$TEST_ROOT/sysupgrade.image" "forced flash"
assert_eq "$(run_su status)" "pending" "snapshot pending after upgrade"

: > "$TEST_ROOT/empty.bin"
if run_su upgrade "$TEST_ROOT/empty.bin"; then
	echo "empty image should be rejected" >&2
	exit 1
fi

echo "OK retry_and_upgrade"
