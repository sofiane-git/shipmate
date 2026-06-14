#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/validate-config.sh"
  TMP="$(mktemp -d)"; cd "$TMP"
  echo '{"version":"1.0.0"}' > package.json
}
teardown() { rm -rf "$TMP"; }
cfg() { cat > "$TMP/.shipmate.json"; }

@test "passes a valid single-contract config" {
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog",
    "locations":[{"file":"package.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -eq 0 ]
}

@test "fails when primaryContract is untagged" {
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"schema",
  "contracts":[{"name":"schema","tag":null,"bumpFrom":"manual",
    "locations":[{"file":"package.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"primaryContract"* ]]
}

@test "fails when primaryContract names no contract" {
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"ghost",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog",
    "locations":[{"file":"package.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
}

@test "fails when a regex location has != 1 capture group" {
  printf 'v 1.0.0 here\n' > install.md
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog",
    "locations":[{"file":"install.md","regex":"v ([0-9]+)\\.([0-9]+)\\.[0-9]+"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"capture group"* ]]
}

@test "fails when two tagged contracts render the same tag" {
  echo '{"version":"1.0.0"}' > a.json
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[
    {"name":"kit","tag":"v{version}","bumpFrom":"changelog","locations":[{"file":"package.json","json":".version"}]},
    {"name":"two","tag":"v{version}","bumpFrom":"changelog","locations":[{"file":"a.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"tag"* ]]
}

@test "fails when a location is unreadable" {
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog",
    "locations":[{"file":"missing.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
}
