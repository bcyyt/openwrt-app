# Test helpers

REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SU_BIN="$REPO_ROOT/stateful-upgrade/files/usr/sbin/stateful-upgrade"
MOCK_DIR="$REPO_ROOT/tests/mocks"

assert_eq() {
	if [ "$1" != "$2" ]; then
		echo "ASSERT EQ FAIL: [$1] != [$2] ($3)" >&2
		exit 1
	fi
}

assert_file() {
	if [ ! -f "$1" ]; then
		echo "ASSERT FILE FAIL: $1 ($2)" >&2
		exit 1
	fi
}

assert_contains() {
	if ! grep -q -- "$2" "$1"; then
		echo "ASSERT CONTAINS FAIL: $1 missing [$2] ($3)" >&2
		exit 1
	fi
}

assert_not_contains() {
	if grep -q -- "$2" "$1"; then
		echo "ASSERT NOT CONTAINS FAIL: $1 has [$2] ($3)" >&2
		exit 1
	fi
}

setup_root() {
	TEST_ROOT="$(mktemp -d)"
	export STATEFUL_ROOT="$TEST_ROOT"
	export STATEFUL_OVERLAY="$TEST_ROOT/overlay/upper"
	export STATEFUL_SKIP_NET=1
	export PATH="$MOCK_DIR:$PATH"
	export SYSUPGRADE_BIN="$MOCK_DIR/sysupgrade"

	mkdir -p \
		"$TEST_ROOT/etc/config" \
		"$TEST_ROOT/etc/dropbear" \
		"$TEST_ROOT/etc/init.d" \
		"$TEST_ROOT/root/.ssh" \
		"$TEST_ROOT/usr/bin" \
		"$TEST_ROOT/usr/lib/opkg/info" \
		"$TEST_ROOT/overlay/upper/usr/bin" \
		"$TEST_ROOT/lib/upgrade/keep.d" \
		"$TEST_ROOT/usr/sbin" \
		"$TEST_ROOT/usr/lib/stateful-upgrade" \
		"$TEST_ROOT/rom/etc/config" \
		"$TEST_ROOT/rom/etc/dropbear" \
		"$TEST_ROOT/var/opkg"

	printf 'root:x:0:0:root:/root:/bin/ash\ndaemon:x:1:1:daemon:/usr/sbin:/bin/false\n' > "$TEST_ROOT/etc/passwd"
	printf 'root:$1$salt$oldhash:19000:0:99999:7:::\ndaemon:*:19000:0:99999:7:::\n' > "$TEST_ROOT/etc/shadow"
	printf "config dropbear\n\toption Port 22\n" > "$TEST_ROOT/etc/config/dropbear"
	printf 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ test@host\n' > "$TEST_ROOT/root/.ssh/authorized_keys"
	printf 'dropbear key\n' > "$TEST_ROOT/etc/dropbear/dropbear_ed25519_host_key"

	printf 'luci-base - 1.0\nluci-app-acme - 2.0\nbusybox - 1.36\n' > "$TEST_ROOT/var/opkg/installed"
	printf '/usr/bin/opkg-owned\n' > "$TEST_ROOT/usr/lib/opkg/info/busybox.list"

	printf '#!/bin/sh\necho overlay-tool\n' > "$TEST_ROOT/overlay/upper/usr/bin/mytool"
	chmod +x "$TEST_ROOT/overlay/upper/usr/bin/mytool"
	printf '#!/bin/sh\necho owned\n' > "$TEST_ROOT/overlay/upper/usr/bin/opkg-owned"
	chmod +x "$TEST_ROOT/overlay/upper/usr/bin/opkg-owned"
	mkdir -p "$TEST_ROOT/usr/bin"
	cp "$TEST_ROOT/overlay/upper/usr/bin/mytool" "$TEST_ROOT/usr/bin/mytool"
	cp "$TEST_ROOT/overlay/upper/usr/bin/opkg-owned" "$TEST_ROOT/usr/bin/opkg-owned"

	cp "$REPO_ROOT/stateful-upgrade/files/lib/upgrade/keep.d/stateful-upgrade" "$TEST_ROOT/lib/upgrade/keep.d/stateful-upgrade"
	cp "$REPO_ROOT/stateful-upgrade/files/etc/init.d/stateful-upgrade" "$TEST_ROOT/etc/init.d/stateful-upgrade"
	chmod +x "$TEST_ROOT/etc/init.d/stateful-upgrade"
	cp "$SU_BIN" "$TEST_ROOT/usr/sbin/stateful-upgrade"
	chmod +x "$TEST_ROOT/usr/sbin/stateful-upgrade"
	cp "$REPO_ROOT/stateful-upgrade/files/usr/lib/stateful-upgrade/"*.sh "$TEST_ROOT/usr/lib/stateful-upgrade/"

	printf '#!/bin/sh\n' > "$TEST_ROOT/etc/init.d/dropbear"
	printf 'echo restarted >> "%s/dropbear.restart"\n' "$TEST_ROOT" >> "$TEST_ROOT/etc/init.d/dropbear"
	printf '[ -f "%s/dropbear.fail" ] && exit 1\nexit 0\n' "$TEST_ROOT" >> "$TEST_ROOT/etc/init.d/dropbear"
	chmod +x "$TEST_ROOT/etc/init.d/dropbear"

	printf 'config dropbear\n\toption Port 22\n' > "$TEST_ROOT/rom/etc/config/dropbear"
}

run_su() {
	"$SU_BIN" "$@"
}
