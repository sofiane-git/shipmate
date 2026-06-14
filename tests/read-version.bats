#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/read-version.sh"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

@test "reads json version via jq filter" {
  echo '{"version":"1.2.3"}' > "$TMP/package.json"
  run "$SCRIPT" "$TMP/package.json" json ".version"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "reads nested json via jq filter" {
  echo '{"plugins":[{"version":"2.0.0"}]}' > "$TMP/m.json"
  run "$SCRIPT" "$TMP/m.json" json ".plugins[0].version"
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "reads toml table.key" {
  printf '[project]\nname = "x"\nversion = "3.4.5"\n' > "$TMP/pyproject.toml"
  run "$SCRIPT" "$TMP/pyproject.toml" toml "project.version"
  [ "$status" -eq 0 ]
  [ "$output" = "3.4.5" ]
}

@test "reads regex capture group 1" {
  printf 'pinned to (currently `9.9.9` here)\n' > "$TMP/install.md"
  run "$SCRIPT" "$TMP/install.md" regex 'currently `([0-9]+\.[0-9]+\.[0-9]+)`'
  [ "$status" -eq 0 ]
  [ "$output" = "9.9.9" ]
}

@test "exits non-zero when json path missing" {
  echo '{}' > "$TMP/package.json"
  run "$SCRIPT" "$TMP/package.json" json ".version"
  [ "$status" -ne 0 ]
}

@test "exits non-zero on unknown type" {
  run "$SCRIPT" "$TMP/whatever" yaml ".x"
  [ "$status" -ne 0 ]
}
