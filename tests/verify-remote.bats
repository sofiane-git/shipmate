#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/verify-remote.sh"
  TMP="$(mktemp -d)"
  REMOTE="$TMP/remote.git"
  WORK="$TMP/work"
  git init -q --bare "$REMOTE"
  git init -q "$WORK"
  cd "$WORK"
  git config user.email t@t.t; git config user.name t
  git commit -q --allow-empty -m init
  git remote add origin "$REMOTE"
}
teardown() { rm -rf "$TMP"; }

@test "passes when the remote exists and is reachable" {
  run "$SCRIPT" origin
  [ "$status" -eq 0 ]
}

@test "fails when the remote does not exist" {
  run "$SCRIPT" nope
  [ "$status" -ne 0 ]
}
