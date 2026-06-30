#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _KUBE_REVAMPED_RENDER_LOADED _TMUX_PLUGIN_TMUX_OPS_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/kube/render.sh"
}

teardown() {
  cleanup_test_environment
}

@test "render.sh - function is defined" {
  function_exists kube_render_segment
}

@test "render.sh - empty context renders nothing" {
  run kube_render_segment ""
  [[ -z "${output}" ]]
}

@test "render.sh - basic context and namespace" {
  run kube_render_segment "prod-ctx" "web"
  [[ "${output}" == "#[fg=blue]prod-ctx:web#[default]" ]]
}

@test "render.sh - namespace can be hidden" {
  set_tmux_option "@kube_revamped_show_namespace" "0"
  run kube_render_segment "prod-ctx" "web"
  [[ "${output}" == "#[fg=blue]prod-ctx#[default]" ]]
}

@test "render.sh - the icon and color are configurable" {
  set_tmux_option "@kube_revamped_icon" "K"
  set_tmux_option "@kube_revamped_color" "#[fg=#89b4fa]"
  run kube_render_segment "prod-ctx" "web"
  [[ "${output}" == "#[fg=#89b4fa]K prod-ctx:web#[default]" ]]
}

@test "render.sh - hide_default suppresses the default context" {
  set_tmux_option "@kube_revamped_hide_default" "1"
  run kube_render_segment "default" "web"
  [[ -z "${output}" ]]
}

@test "render.sh - hide_default keeps a non-default context" {
  set_tmux_option "@kube_revamped_hide_default" "1"
  run kube_render_segment "prod-ctx" "web"
  [[ "${output}" == "#[fg=blue]prod-ctx:web#[default]" ]]
}

@test "render.sh - a matching prod pattern uses the prod color" {
  set_tmux_option "@kube_revamped_prod_pattern" "prod"
  run kube_render_segment "prod-ctx" "web"
  [[ "${output}" == "#[fg=red]prod-ctx:web#[default]" ]]
}

@test "render.sh - prod color is configurable" {
  set_tmux_option "@kube_revamped_prod_pattern" "prod"
  set_tmux_option "@kube_revamped_prod_color" "#[fg=magenta]"
  run kube_render_segment "prod-ctx" "web"
  [[ "${output}" == "#[fg=magenta]prod-ctx:web#[default]" ]]
}

@test "render.sh - a non-matching prod pattern keeps the base color" {
  set_tmux_option "@kube_revamped_prod_pattern" "prod"
  run kube_render_segment "dev-ctx" "web"
  [[ "${output}" == "#[fg=blue]dev-ctx:web#[default]" ]]
}

@test "render.sh - show_cluster appends the cluster" {
  set_tmux_option "@kube_revamped_show_cluster" "1"
  run kube_render_segment "prod-ctx" "web" "" "prod-cluster"
  [[ "${output}" == "#[fg=blue]prod-ctx@prod-cluster:web#[default]" ]]
}

@test "render.sh - show_cluster with an empty cluster adds nothing" {
  set_tmux_option "@kube_revamped_show_cluster" "1"
  run kube_render_segment "prod-ctx" "web" "" ""
  [[ "${output}" == "#[fg=blue]prod-ctx:web#[default]" ]]
}

@test "render.sh - show_user appends the user" {
  set_tmux_option "@kube_revamped_show_user" "1"
  run kube_render_segment "prod-ctx" "web" "" "" "admin"
  [[ "${output}" == "#[fg=blue]prod-ctx:web (admin)#[default]" ]]
}

@test "render.sh - show_user with an empty user adds nothing" {
  set_tmux_option "@kube_revamped_show_user" "1"
  run kube_render_segment "prod-ctx" "web" "" "" ""
  [[ "${output}" == "#[fg=blue]prod-ctx:web#[default]" ]]
}

@test "render.sh - a dangling context uses the warn color and marker" {
  run kube_render_segment "ghost-ctx" "" "1"
  [[ "${output}" == "#[fg=yellow]ghost-ctx ?#[default]" ]]
}

@test "render.sh - the warn color and icon are configurable" {
  set_tmux_option "@kube_revamped_warn_color" "#[fg=orange]"
  set_tmux_option "@kube_revamped_warn_icon" "!"
  run kube_render_segment "ghost-ctx" "" "1"
  [[ "${output}" == "#[fg=orange]ghost-ctx !#[default]" ]]
}

@test "render.sh - cluster, user, and icon combine" {
  set_tmux_option "@kube_revamped_icon" "K"
  set_tmux_option "@kube_revamped_show_cluster" "1"
  set_tmux_option "@kube_revamped_show_user" "1"
  run kube_render_segment "prod-ctx" "web" "" "c1" "u1"
  [[ "${output}" == "#[fg=blue]K prod-ctx@c1:web (u1)#[default]" ]]
}
