#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-preconditions.sh"
  TMP="$(mktemp -d)"
  REMOTE="$TMP/remote.git"
  WORK="$TMP/work"
  git init -q --bare "$REMOTE"
  git init -q "$WORK"
  cd "$WORK"
  git config user.email t@t.t; git config user.name t
  git commit -q --allow-empty -m init
  git remote add origin "$REMOTE"
  git push -q -u origin HEAD:main
  export SHIPMATE_SKIP_GH_CHECK=1
}
teardown() { rm -rf "$TMP"; }

@test "passes on a clean, up-to-date tree" {
  run "$SCRIPT" origin
  [ "$status" -eq 0 ]
}

@test "fails on a dirty working tree" {
  echo dirty > file.txt
  run "$SCRIPT" origin
  [ "$status" -ne 0 ]
  [[ "$output" == *"working tree"* ]]
}
