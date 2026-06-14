#!/usr/bin/env bats
setup() { S="$BATS_TEST_DIRNAME/../scripts/diff-touches-code.sh"; }

@test "code-less when only docs + changelog + config change" {
  run bash -c "printf 'CHANGELOG.md\ndocs/install.md\n.shipmate.json\npackage.json\n' | '$S'"
  [ "$status" -eq 10 ]
}
@test "touches code when a source file changes" {
  run bash -c "printf 'CHANGELOG.md\nsrc/index.ts\n' | '$S'"
  [ "$status" -eq 0 ]
}
@test "touches code for a python source change" {
  run bash -c "printf 'app/main.py\n' | '$S'"
  [ "$status" -eq 0 ]
}
