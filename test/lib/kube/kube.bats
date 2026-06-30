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

@test "kube.sh - kube_current_context takes the last non-empty across files" {
  local merged
  merged=$(printf 'current-context: first\n\ncurrent-context: second\n')
  [[ "$(kube_current_context "${merged}")" == "second" ]]
}

@test "kube.sh - kube_current_context ignores an empty later value" {
  local merged
  merged=$(printf 'current-context: keep\n\ncurrent-context: ""\n')
  [[ "$(kube_current_context "${merged}")" == "keep" ]]
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

@test "kube.sh - kube_cluster_for reads the cluster of a context" {
  [[ "$(kube_cluster_for "${CFG}" "prod-ctx")" == "prod" ]]
}

@test "kube.sh - kube_cluster_for is empty for an unknown context" {
  [[ -z "$(kube_cluster_for "${CFG}" "nope-ctx")" ]]
}

@test "kube.sh - kube_user_for reads the user of a context" {
  [[ "$(kube_user_for "${CFG}" "prod-ctx")" == "admin" ]]
}

@test "kube.sh - kube_user_for is empty for an unknown context" {
  [[ -z "$(kube_user_for "${CFG}" "nope-ctx")" ]]
}

@test "kube.sh - kube_list_contexts lists every context name" {
  run kube_list_contexts "${CFG}"
  [[ "${lines[0]}" == "prod-ctx" ]]
  [[ "${lines[1]}" == "dev-ctx" ]]
}

@test "kube.sh - kube_context_exists is true for a known context" {
  kube_context_exists "${CFG}" "dev-ctx"
}

@test "kube.sh - kube_context_exists is false for an unknown context" {
  ! kube_context_exists "${CFG}" "ghost-ctx"
}

@test "kube.sh - kube_context_exists is false for an empty name" {
  ! kube_context_exists "${CFG}" ""
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

@test "kube.sh - _kube_config_files honors the full KUBECONFIG list" {
  export KUBECONFIG="/a/one:/b/two:/c/three"
  run _kube_config_files
  [[ "${lines[0]}" == "/a/one" ]]
  [[ "${lines[1]}" == "/b/two" ]]
  [[ "${lines[2]}" == "/c/three" ]]
}

@test "kube.sh - _kube_config_files falls back to the default path" {
  unset KUBECONFIG
  run _kube_config_files
  [[ "${output}" == "${HOME}/.kube/config" ]]
}

@test "kube.sh - _kube_config_text merges every file with last context winning" {
  local f1 f2
  f1="${TEST_TMPDIR}/one.yaml"
  f2="${TEST_TMPDIR}/two.yaml"
  cat > "${f1}" <<'YAML'
contexts:
- context:
    namespace: a-ns
  name: a-ctx
current-context: a-ctx
YAML
  cat > "${f2}" <<'YAML'
contexts:
- context:
    namespace: b-ns
  name: b-ctx
current-context: b-ctx
YAML
  export KUBECONFIG="${f1}:${f2}"
  local yaml
  yaml="$(_kube_config_text)"
  [[ "$(kube_current_context "${yaml}")" == "b-ctx" ]]
  kube_context_exists "${yaml}" "a-ctx"
  kube_context_exists "${yaml}" "b-ctx"
  [[ "$(kube_namespace_for "${yaml}" "a-ctx")" == "a-ns" ]]
}

@test "kube.sh - config-read seam reads a fixture file" {
  local f
  f="${TEST_TMPDIR}/cfg.yaml"
  printf 'current-context: fix-ctx\n' > "${f}"
  export KUBECONFIG="${f}"
  run _kube_config_text
  [[ "${output}" == *"fix-ctx"* ]]
}

@test "kube.sh - _kube_config_files skips empty entries" {
  export KUBECONFIG="/a/one::/b/two"
  run _kube_config_files
  [[ "${#lines[@]}" -eq 2 ]]
  [[ "${lines[0]}" == "/a/one" ]]
  [[ "${lines[1]}" == "/b/two" ]]
}
