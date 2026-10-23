#!/bin/sh
set -e
DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
failed=0
for t in "$DIR"/0*.sh; do
	echo "==> $t"
	if sh "$t"; then
		echo "PASS $t"
	else
		echo "FAIL $t"
		failed=1
	fi
done
if [ "$failed" -ne 0 ]; then
	exit 1
fi
echo "ALL PASS"
