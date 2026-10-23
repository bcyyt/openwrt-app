#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"
setup_root

run_su snapshot

printf 'luci-base - 1.0\nluci-app-extra - 9.0\nbusybox - 1.36\nluci - 1.0\n' > "$TEST_ROOT/var/opkg/installed"
printf 'root:x:0:0:root:/root:/bin/ash\ndaemon:x:1:1:daemon:/usr/sbin:/bin/false\nnewuser:x:1000:1000:n:/home/n:/bin/ash\n' > "$TEST_ROOT/etc/passwd"
printf 'root:$1$salt$NEWHASH:19000:0:99999:7:::\ndaemon:*:19000:0:99999:7:::\nnewuser:*:19000:0:99999:7:::\n' > "$TEST_ROOT/etc/shadow"
printf "config dropbear\n\toption Port 2222\n" > "$TEST_ROOT/etc/config/dropbear"
mv "$TEST_ROOT/usr/bin/mytool" "$TEST_ROOT/usr/bin/mytool.gone"

run_su restore
assert_eq "$(run_su status)" "completed" "restore completed"

assert_contains "$TEST_ROOT/etc/passwd" 'root:x:0:0:root:/root:/bin/ash' "root passwd restored"
assert_contains "$TEST_ROOT/etc/passwd" 'newuser:x:1000:1000:n:/home/n:/bin/ash' "other users kept"
assert_contains "$TEST_ROOT/etc/shadow" 'oldhash' "root hash restored"
assert_contains "$TEST_ROOT/etc/config/dropbear" 'option Port 22' "dropbear port restored"
assert_file "$TEST_ROOT/usr/bin/mytool" "custom binary restored"
assert_contains "$TEST_ROOT/var/opkg/installed" "luci-app-acme" "missing plugin installed"
assert_not_contains "$TEST_ROOT/var/opkg/installed" "luci-app-extra" "extra plugin removed"
assert_contains "$TEST_ROOT/var/opkg/installed" "luci-base" "snapshot plugin kept"
assert_contains "$TEST_ROOT/var/opkg/installed" "luci - " "new essential kept"
assert_contains "$TEST_ROOT/etc/stateful-upgrade/skipped_essential.txt" "luci" "essential skip listed"

report="$(run_su report)"
echo "$report" | grep -q 'luci-app-acme'
echo "$report" | grep -q 'luci-app-extra'

run_su restore
assert_eq "$(run_su status)" "completed" "consumed snapshot"

echo "OK restore"
