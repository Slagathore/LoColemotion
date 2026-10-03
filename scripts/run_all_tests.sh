#!/usr/bin/env bash
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

passed=0
failed=()
while IFS= read -r test_file; do
  name="$(basename "$test_file")"
  echo "=== $name ==="
  "$GODOT" --headless --path "$REPO" --script "res://tests/$name"
  code=$?
  if [[ $code -eq 0 ]]; then
    passed=$((passed + 1))
    echo "PASS $name"
  else
    failed+=("$name")
    echo "FAIL $name exit=$code"
  fi
done < <(find "$REPO/tests" -maxdepth 1 -name 'test_*.gd' | sort)

total=$((passed + ${#failed[@]}))
echo "SUMMARY total=$total passed=$passed failed=${#failed[@]}"
if [[ ${#failed[@]} -gt 0 ]]; then
  printf 'FAILED: %s\n' "${failed[*]}"
  exit 1
fi
exit 0
