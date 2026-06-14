#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/discover-versions.sh"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

@test "finds package.json version" {
  echo '{"version":"1.2.3"}' > "$TMP/package.json"
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[] | select(.file=="package.json" and .version=="1.2.3")'
}

@test "finds pyproject.toml version" {
  printf '[project]\nversion = "4.5.6"\n' > "$TMP/pyproject.toml"
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[] | select(.file=="pyproject.toml" and .version=="4.5.6")'
}

@test "finds claude plugin manifests" {
  mkdir -p "$TMP/.claude-plugin"
  echo '{"version":"0.1.0"}' > "$TMP/.claude-plugin/plugin.json"
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[] | select(.file==".claude-plugin/plugin.json")'
}

@test "finds prose currently-version markers" {
  mkdir -p "$TMP/docs"
  printf 'pinned (currently `7.8.9` here)\n' > "$TMP/docs/install.md"
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[] | select(.file=="docs/install.md" and .version=="7.8.9")'
}

@test "emits empty array when nothing found" {
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq 'length')" -eq 0 ]
}
