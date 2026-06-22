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
