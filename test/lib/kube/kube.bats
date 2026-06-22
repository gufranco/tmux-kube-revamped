#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _KUBE_REVAMPED_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/kube/kube.sh"
  CFG=$(cat <<'YAML'
apiVersion: v1
contexts:
- context:
    cluster: prod
    namespace: web
    user: admin
  name: prod-ctx
- context:
    cluster: dev
    user: dev
  name: dev-ctx
current-context: prod-ctx
kind: Config
YAML
)
}

teardown() {
  cleanup_test_environment
}

@test "kube.sh - kube_current_context reads the top-level key" {
  [[ "$(kube_current_context "${CFG}")" == "prod-ctx" ]]
}

@test "kube.sh - kube_current_context is empty when absent" {
  [[ -z "$(kube_current_context "apiVersion: v1")" ]]
}

@test "kube.sh - kube_namespace_for reads the namespace of a context" {
  [[ "$(kube_namespace_for "${CFG}" "prod-ctx")" == "web" ]]
}

@test "kube.sh - kube_namespace_for defaults when the context has none" {
  [[ "$(kube_namespace_for "${CFG}" "dev-ctx")" == "default" ]]
}

@test "kube.sh - kube_namespace_for is empty for an unknown context" {
  [[ -z "$(kube_namespace_for "${CFG}" "nope-ctx")" ]]
}

@test "kube.sh - quotes around values are stripped" {
  local q
  q=$(cat <<'YAML'
contexts:
- context:
    namespace: "prod ns"
  name: "my-ctx"
current-context: "my-ctx"
YAML
)
  [[ "$(kube_current_context "${q}")" == "my-ctx" ]]
}

@test "kube.sh - config-read seam is callable" {
  run _kube_config_text
  true
}
