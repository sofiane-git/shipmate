#!/usr/bin/env bats
setup() {
  S="$BATS_TEST_DIRNAME/../scripts/release-rollback.sh"
  TMP="$(mktemp -d)"; cd "$TMP"
  git init -q; git config user.email t@t.t; git config user.name t
  echo base > f.txt; git add f.txt; git commit -qm init
}
teardown() { rm -rf "$TMP"; }

@test "deletes a local tag" {
  git tag v1.0.0
  "$S" tag v1.0.0
  run git tag -l v1.0.0
  [ -z "$output" ]
}
@test "deleting a missing tag is a no-op (idempotent)" {
  run "$S" tag v9.9.9
  [ "$status" -eq 0 ]
}
@test "deletes a local branch" {
  git branch release/x
  "$S" branch release/x
  run git branch --list release/x
  [ -z "$output" ]
}
@test "restores a file from HEAD" {
  echo changed > f.txt
  "$S" restore f.txt
  [ "$(cat f.txt)" = "base" ]
}
