#!/usr/bin/env bash
# Runs the headless unit tests and returns their exit code, never a pipe's.
# Usage: tests/run.sh [test_file_basename]
cd "$(dirname "$0")/.." || exit 2
args=()
[ -n "$1" ] && args=(-- "--only=$1")
out=$(godot4 --headless --fixed-fps 60 --path . -s tests/run_tests.gd "${args[@]}" 2>&1)
code=$?
echo "$out" | grep -E "^(FAIL|TESTS)|SCRIPT ERROR|Parse Error" | head -40
exit $code
