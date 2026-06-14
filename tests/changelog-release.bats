#!/usr/bin/env bats
setup() {
  S="$BATS_TEST_DIRNAME/../scripts/changelog-release.sh"
  TMP="$(mktemp -d)"
  cat > "$TMP/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]

### Fixed
- A bug.
MD
}
teardown() { rm -rf "$TMP"; }

@test "restructure renames Unreleased and inserts a fresh one" {
  "$S" restructure "$TMP/CHANGELOG.md" 1.2.0 2026-06-14
  grep -q "## \[1.2.0\] — 2026-06-14" "$TMP/CHANGELOG.md"
  run grep -n "## \[Unreleased\]" "$TMP/CHANGELOG.md"
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 1 ]
  awk '/## \[1.2.0\]/{f=1} f&&/A bug/{found=1} END{exit !found}' "$TMP/CHANGELOG.md"
}

@test "extract prints a version's section body only" {
  "$S" restructure "$TMP/CHANGELOG.md" 1.2.0 2026-06-14
  run "$S" extract "$TMP/CHANGELOG.md" 1.2.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"A bug"* ]]
  [[ "$output" != *"Unreleased"* ]]
}
