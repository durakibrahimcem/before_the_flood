#!/usr/bin/env bash
# Quality gate. Run from the repo root: tools/gate.sh
set -u
root=$(git rev-parse --show-toplevel); cd "$root" || exit 2
fail() { echo "GATE FAIL: $1"; exit 1; }

timeout 300 tools/g --headless --path game --import >/tmp/gate-import.$$ 2>&1 || { tail -5 /tmp/gate-import.$$; rm -f /tmp/gate-import.$$; fail "import failed"; }
rm -f /tmp/gate-import.$$
timeout 120 tools/g --headless --path game --script tools/check.gd || fail "a script or scene is broken"
timeout 120 tools/g --headless --path game --script tests/test_sim.gd || fail "simulation tests failed"

while IFS= read -r scene; do
	res="res://${scene#game/}"
	log=$(timeout 90 tools/g --headless --path game "$res" 2>&1)
	status=$?
	if echo "$log" | grep -E 'SCRIPT ERROR|USER ERROR|^ERROR:|Parse Error|Invalid call|Invalid access|Nonexistent function|Node not found' | grep -vE 'PulseAudio|dri3|nouveau|resources still in use|ObjectDB' | grep -q .; then
		echo "$log" | grep -E 'SCRIPT ERROR|USER ERROR|^ERROR:|Parse Error|Invalid|Nonexistent|Node not found' | head -8
		fail "$res logged errors"
	fi
	[ "$status" -eq 0 ] || fail "$res exited with $status"
	echo "$log" | grep -q "DEMO PASS" || fail "$res did not print DEMO PASS"
	echo "ok  $res"
done < <(find game -name '*_demo.tscn' -not -path '*/.godot/*' | sort)
echo "GATE PASS"
