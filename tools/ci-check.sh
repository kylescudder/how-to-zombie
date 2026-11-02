#!/usr/bin/env bash
# Godot can report script errors while returning zero; inspect logs as well.
set -euo pipefail
cd "$(dirname "$0")/.."
suite="${1:-settings}"
case "$suite" in settings|guns|solo|campaign) ;; *) echo "Unknown CI suite: $suite" >&2; exit 2 ;; esac
mkdir -p .tools/ci
check_log() {
  if grep -E 'SCRIPT ERROR:|(^|[[:space:]])ERROR:' "$1"; then
    echo "Godot errors in $1" >&2
    exit 1
  fi
}
"${GODOT:-godot}" --headless --path . --import 2>&1 | tee ".tools/ci/import-$suite.log"
check_log ".tools/ci/import-$suite.log"
"${GODOT:-godot}" --headless --path . --fixed-fps 60 -- --solo --linear "--test=$suite" 2>&1 | tee ".tools/ci/$suite.log"
check_log ".tools/ci/$suite.log"
grep -Fx "[TEST] $suite: PASS" ".tools/ci/$suite.log"
