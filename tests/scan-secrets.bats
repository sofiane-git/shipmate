#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/scan-secrets.sh"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

@test "passes on clean release notes" {
  printf '## [1.2.0]\n- Fixed a bug in the parser.\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -eq 0 ]
}

@test "fails on a GitHub token" {
  printf 'token: ghp_0123456789abcdef0123456789abcdef0123\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "fails on a private key header" {
  printf -- '-----BEGIN RSA PRIVATE KEY-----\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "fails on an AWS access key id" {
  printf 'AKIAIOSFODNN7EXAMPLE\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "fails on a Google API key" {
  printf 'AIzaSyA1234567890abcdefghijklmnopqrstuv0\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "fails on a GitLab token" {
  printf 'glpat-abcdefghij1234567890\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "fails on a Stripe live secret key" {
  # assembled from parts so this fixture is not itself flagged by upstream secret scanners
  printf 'sk_%s_0123456789abcdefghijklmn\n' 'live' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "fails on an npm token" {
  printf 'npm_0123456789abcdef0123456789abcdef0123\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "reads from stdin when no file given" {
  run bash -c "printf 'ghp_0123456789abcdef0123456789abcdef0123\n' | '$SCRIPT'"
  [ "$status" -ne 0 ]
}
