#!/usr/bin/env bats

setup() {
  W="$BATS_TEST_DIRNAME/../scripts/write-version.sh"
  R="$BATS_TEST_DIRNAME/../scripts/read-version.sh"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

@test "writes json version" {
  echo '{"version":"1.0.0"}' > "$TMP/package.json"
  "$W" "$TMP/package.json" json ".version" "2.0.0"
  [ "$("$R" "$TMP/package.json" json ".version")" = "2.0.0" ]
}

@test "writes nested json version" {
  echo '{"plugins":[{"version":"1.0.0"}]}' > "$TMP/m.json"
  "$W" "$TMP/m.json" json ".plugins[0].version" "3.1.0"
  [ "$("$R" "$TMP/m.json" json ".plugins[0].version")" = "3.1.0" ]
}

@test "writes toml version, leaving other keys intact" {
  printf '[project]\nname = "x"\nversion = "1.0.0"\n' > "$TMP/pyproject.toml"
  "$W" "$TMP/pyproject.toml" toml "project.version" "2.2.2"
  [ "$("$R" "$TMP/pyproject.toml" toml "project.version")" = "2.2.2" ]
  grep -q 'name = "x"' "$TMP/pyproject.toml"
}

@test "writes regex capture group 1, leaving surrounding text intact" {
  printf 'pinned (currently `1.0.0` here)\n' > "$TMP/install.md"
  "$W" "$TMP/install.md" regex 'currently `([0-9]+\.[0-9]+\.[0-9]+)`' "9.9.9"
  grep -q 'currently `9.9.9` here' "$TMP/install.md"
}
