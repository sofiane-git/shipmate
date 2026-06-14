#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/version-sync-check.sh"
  TMP="$(mktemp -d)"
  cd "$TMP"
}
teardown() { rm -rf "$TMP"; }

write_config() { cat > "$TMP/.shipmate.json"; }

@test "passes when both locations of a contract agree" {
  echo '{"version":"1.0.0"}' > package.json
  printf '[project]\nversion = "1.0.0"\n' > pyproject.toml
  write_config <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog","locations":[
    {"file":"package.json","json":".version"},
    {"file":"pyproject.toml","toml":"project.version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -eq 0 ]
}

@test "fails when locations disagree (drift)" {
  echo '{"version":"1.0.0"}' > package.json
  printf '[project]\nversion = "1.0.1"\n' > pyproject.toml
  write_config <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog","locations":[
    {"file":"package.json","json":".version"},
    {"file":"pyproject.toml","toml":"project.version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"kit"* ]]
  [[ "$output" == *"1.0.0"* ]]
  [[ "$output" == *"1.0.1"* ]]
}

@test "checks each contract independently" {
  echo '{"version":"1.0.0"}' > package.json
  echo '{"const":"2.0"}' > schema.json
  write_config <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[
    {"name":"kit","tag":"v{version}","bumpFrom":"changelog","locations":[{"file":"package.json","json":".version"}]},
    {"name":"schema","tag":null,"bumpFrom":"manual","locations":[{"file":"schema.json","json":".const"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -eq 0 ]
}
