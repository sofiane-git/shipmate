#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-tag-unpushed.sh"
  TMP="$(mktemp -d)"
  REMOTE="$TMP/remote.git"
  WORK="$TMP/work"
  git init -q --bare "$REMOTE"
  git init -q "$WORK"
  cd "$WORK"
  git config user.email t@t.t; git config user.name t
  git commit -q --allow-empty -m init
  git remote add origin "$REMOTE"
  git push -q origin HEAD:main
}
teardown() { rm -rf "$TMP"; }

@test "passes when the tag is not on the remote" {
  run "$SCRIPT" origin v1.0.0
  [ "$status" -eq 0 ]
}

@test "fails when the tag already exists on the remote" {
  git tag v1.0.0
  git push -q origin v1.0.0
  run "$SCRIPT" origin v1.0.0
  [ "$status" -ne 0 ]
  [[ "$output" == *"v1.0.0"* ]]
}
