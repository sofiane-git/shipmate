#!/usr/bin/env bats
setup() { S="$BATS_TEST_DIRNAME/../scripts/render-tag.sh"; }

@test "renders version-only template" {
  run "$S" "v{version}" kit 1.2.3
  [ "$status" -eq 0 ]; [ "$output" = "v1.2.3" ]
}
@test "renders name+version template" {
  run "$S" "{name}-v{version}" schema 2.0.0
  [ "$status" -eq 0 ]; [ "$output" = "schema-v2.0.0" ]
}
@test "errors on null/empty template" {
  run "$S" "" kit 1.0.0
  [ "$status" -ne 0 ]
}
