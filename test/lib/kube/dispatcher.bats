#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _KUBE_REVAMPED_LOADED _KUBE_REVAMPED_RENDER_LOADED
  export CACHE_SYNC=1
  source "${BATS_TEST_DIRNAME}/../../../src/kube.sh"
  _kube_config_text() {
    cat <<'YAML'
contexts:
- context:
    namespace: web
  name: prod-ctx
current-context: prod-ctx
YAML
  }
}

teardown() {
  cleanup_test_environment
}

@test "kube.sh dispatcher - functions are defined" {
  function_exists main
  function_exists kube_refresh
  function_exists kube_render
}

@test "kube.sh dispatcher - kube renders context and namespace" {
  run main kube
  [[ "${output}" == "#[fg=blue]prod-ctx:web#[default]" ]]
}

@test "kube.sh dispatcher - context and namespace subcommands" {
  run main context
  [[ "${output}" == "prod-ctx" ]]
  run main namespace
  [[ "${output}" == "web" ]]
}

@test "kube.sh dispatcher - the icon and color are configurable" {
  set_tmux_option "@kube_revamped_icon" "K"
  set_tmux_option "@kube_revamped_color" "#[fg=#89b4fa]"
  run main kube
  [[ "${output}" == "#[fg=#89b4fa]K prod-ctx:web#[default]" ]]
}

@test "kube.sh dispatcher - namespace can be hidden" {
  set_tmux_option "@kube_revamped_show_namespace" "0"
  run main kube
  [[ "${output}" == "#[fg=blue]prod-ctx#[default]" ]]
}

@test "kube.sh dispatcher - empty when not in a cluster" {
  _kube_config_text() { echo "apiVersion: v1"; }
  run main kube
  [[ -z "${output}" ]]
}

@test "kube.sh dispatcher - hide_default suppresses the default context" {
  _kube_config_text() { printf 'current-context: default\n'; }
  set_tmux_option "@kube_revamped_hide_default" "1"
  run main kube
  [[ -z "${output}" ]]
}

@test "kube.sh dispatcher - refresh subcommand caches the value" {
  run main refresh
  [[ "$(cache_get value)" == "prod-ctx|web" ]]
}

@test "kube.sh dispatcher - unknown subcommand produces no output" {
  run main bogus
  [[ -z "${output}" ]]
}

@test "kube.sh dispatcher - refresh caches dangling, cluster, and user" {
  _kube_config_text() {
    cat <<'YAML'
contexts:
- context:
    cluster: prod-cluster
    namespace: web
    user: admin
  name: prod-ctx
current-context: prod-ctx
YAML
  }
  run main refresh
  [[ "$(cache_get value)" == "prod-ctx|web" ]]
  [[ -z "$(cache_get dangling)" ]]
  [[ "$(cache_get cluster)" == "prod-cluster" ]]
  [[ "$(cache_get user)" == "admin" ]]
}

@test "kube.sh dispatcher - a dangling context renders the warning" {
  _kube_config_text() { printf 'contexts:\n- context:\n  name: real-ctx\ncurrent-context: ghost-ctx\n'; }
  run main kube
  [[ "${output}" == "#[fg=yellow]ghost-ctx ?#[default]" ]]
}

@test "kube.sh dispatcher - show_cluster and show_user enrich the segment" {
  _kube_config_text() {
    cat <<'YAML'
contexts:
- context:
    cluster: prod-cluster
    namespace: web
    user: admin
  name: prod-ctx
current-context: prod-ctx
YAML
  }
  set_tmux_option "@kube_revamped_show_cluster" "1"
  set_tmux_option "@kube_revamped_show_user" "1"
  run main kube
  [[ "${output}" == "#[fg=blue]prod-ctx@prod-cluster:web (admin)#[default]" ]]
}

@test "kube.sh dispatcher - use-context switches and refreshes" {
  _kubectl() { printf '%s\n' "$*" > "${TEST_TMPDIR}/applied"; }
  run main use-context dev-ctx
  grep -q "config use-context dev-ctx" "${TEST_TMPDIR}/applied"
}

@test "kube.sh dispatcher - use-context ignores an empty name" {
  _kubectl() { echo "called" > "${TEST_TMPDIR}/applied"; }
  run main use-context
  [[ ! -f "${TEST_TMPDIR}/applied" ]]
}

@test "kube.sh dispatcher - use-namespace switches and refreshes" {
  _kubectl() { printf '%s\n' "$*" > "${TEST_TMPDIR}/applied"; }
  run main use-namespace web
  grep -q "config set-context --current --namespace web" "${TEST_TMPDIR}/applied"
}

@test "kube.sh dispatcher - use-namespace ignores an empty name" {
  _kubectl() { echo "called" > "${TEST_TMPDIR}/applied"; }
  run main use-namespace
  [[ ! -f "${TEST_TMPDIR}/applied" ]]
}

@test "kube.sh dispatcher - menu-context emits a menu" {
  _tmux() { printf '%s\n' "$*"; }
  run main menu-context
  [[ "${output}" == *"display-menu -T Context"* ]]
  [[ "${output}" == *"use-context prod-ctx"* ]]
}

@test "kube.sh dispatcher - menu-namespace emits a menu" {
  _kubectl() { printf 'namespace/web\n'; }
  _tmux() { printf '%s\n' "$*"; }
  run main menu-namespace
  [[ "${output}" == *"display-menu -T Namespace"* ]]
  [[ "${output}" == *"use-namespace web"* ]]
}

@test "kube.sh dispatcher - popup opens k9s" {
  _kube_tmux_version_string() { echo "tmux 3.3"; }
  _tmux() { printf '%s\n' "$*"; }
  main refresh
  run main popup
  [[ "${output}" == *"display-popup"* ]]
  [[ "${output}" == *"k9s --context prod-ctx --namespace web"* ]]
}

@test "kube.sh dispatcher - bind-keys binds a configured key" {
  set_tmux_option "@kube_revamped_popup_key" "K"
  _tmux() { printf '%s\n' "$*"; }
  run main bind-keys
  [[ "${output}" == *"bind-key K run-shell"* ]]
  [[ "${output}" == *"popup"* ]]
}

@test "kube.sh dispatcher - doctor prints a report" {
  run main doctor
  [[ "${output}" == *"tmux-kube-revamped doctor"* ]]
}

@test "kube.sh dispatcher - health badges follow an enabled reach probe" {
  set_tmux_option "@kube_revamped_probe_reach" "1"
  _kubectl() { return 0; }
  main refresh
  run main kube
  [[ "${output}" == *"prod-ctx:web"* ]]
  [[ "${output}" == *"#[fg=green]o#[default]"* ]]
}

@test "kube.sh dispatcher - a non-numeric interval falls back to the default" {
  set_tmux_option "@kube_revamped_interval" "abc"
  [[ "$(kube_max_age)" == "10" ]]
}

@test "kube.sh dispatcher - kube_render handles a value with no namespace field" {
  run kube_render "soloctx"
  [[ "${output}" == "#[fg=blue]soloctx#[default]" ]]
}
