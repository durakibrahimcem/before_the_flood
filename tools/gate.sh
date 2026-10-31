#!/usr/bin/env bash
# Quality gate. Run from a worktree root: tools/gate.sh [mission-id]
# With a mission id it also checks that only allowed paths changed.
set -u
root=$(git rev-parse --show-toplevel); cd "$root" || exit 2
mission=${1:-}
fail() { echo "GATE FAIL: $1"; exit 1; }

if [ -n "$mission" ]; then
	allow="docs/missions/$mission.allow"
	[ -f "$allow" ] || fail "no allow file for $mission"
	[ -f "docs/missions/reports/$mission.md" ] || fail "no mission report at docs/missions/reports/$mission.md"
	[ -z "$(git status --porcelain)" ] || fail "uncommitted changes"
	base=$(git merge-base develop HEAD)
	[ -n "$base" ] || fail "no merge-base with develop"
	while IFS= read -r path; do
		ok=no
		while IFS= read -r pattern; do
			[ -z "$pattern" ] && continue
			case "$path" in $pattern) ok=yes;; esac
		done < "$allow"
		case "$path" in "docs/missions/reports/$mission.md") ok=yes;; esac
		[ "$ok" = yes ] || fail "changed a file outside its folder: $path"
	done < <(git diff --name-only "$base" HEAD)
fi

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
