#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _KUBE_REVAMPED_CLUSTER_LOADED
  export CACHE_PREFIX="kube_revamped"
  export CACHE_SYNC=1
  source "${BATS_TEST_DIRNAME}/../../../src/lib/kube/cluster.sh"
}

teardown() {
  cleanup_test_environment
}

@test "cluster.sh - functions are defined" {
  function_exists kube_reach_ok
  function_exists kube_parse_nodes
  function_exists kube_parse_pods
  function_exists kube_probe_all
  function_exists kube_health_segment
}

@test "cluster.sh - _kubectl seam dispatches to kubectl" {
  kubectl() { echo "stub $*"; }
  run _kubectl get pods
  [[ "${output}" == "stub get pods" ]]
}

@test "cluster.sh - kube_parse_nodes counts ready over total" {
  run kube_parse_nodes "$(printf 'n1 Ready a b c\nn2 NotReady a b c\nn3 Ready a b c\n')"
  [[ "${output}" == "2/3" ]]
}

@test "cluster.sh - kube_parse_nodes is 0/0 for empty input" {
  run kube_parse_nodes ""
  [[ "${output}" == "0/0" ]]
}

@test "cluster.sh - kube_parse_pods counts non-running pods" {
  run kube_parse_pods "$(printf 'p1 1/1 Running 0 1m\np2 0/1 CrashLoopBackOff 5 2m\np3 0/1 Completed 0 3m\np4 0/1 Pending 0 4m\n')"
  [[ "${output}" == "2" ]]
}

@test "cluster.sh - kube_parse_pods is 0 when all healthy" {
  run kube_parse_pods "$(printf 'p1 1/1 Running 0 1m\np2 0/1 Completed 0 2m\n')"
  [[ "${output}" == "0" ]]
}

@test "cluster.sh - kube_reach_ok is true when the cluster answers" {
  _kubectl() { return 0; }
  kube_reach_ok
}

@test "cluster.sh - kube_reach_ok is false when the cluster is down" {
  _kubectl() { return 1; }
  ! kube_reach_ok
}

@test "cluster.sh - kube_nodes_state parses the kubectl output" {
  _kubectl() { printf 'n1 Ready a b c\nn2 Ready a b c\n'; }
  run kube_nodes_state
  [[ "${output}" == "2/2" ]]
}

@test "cluster.sh - kube_nodes_state is empty on a failed call" {
  _kubectl() { return 1; }
  run kube_nodes_state
  [[ -z "${output}" ]]
}

@test "cluster.sh - kube_nodes_state is empty on empty output" {
  _kubectl() { printf ''; }
  run kube_nodes_state
  [[ -z "${output}" ]]
}

@test "cluster.sh - kube_pods_state parses the kubectl output" {
  _kubectl() { printf 'p1 1/1 Running 0 1m\np2 0/1 Pending 0 2m\n'; }
  run kube_pods_state
  [[ "${output}" == "1" ]]
}

@test "cluster.sh - kube_pods_state is empty on a failed call" {
  _kubectl() { return 1; }
  run kube_pods_state
  [[ -z "${output}" ]]
}

@test "cluster.sh - kube_pods_state is empty on empty output" {
  _kubectl() { printf ''; }
  run kube_pods_state
  [[ -z "${output}" ]]
}

@test "cluster.sh - kube_list_namespaces strips the resource prefix" {
  _kubectl() { printf 'namespace/default\nnamespace/kube-system\n'; }
  run kube_list_namespaces
  [[ "${lines[0]}" == "default" ]]
  [[ "${lines[1]}" == "kube-system" ]]
}

@test "cluster.sh - kube_apply_context is a no-op for an empty name" {
  _kubectl() { echo "called" > "${TEST_TMPDIR}/k"; }
  ! kube_apply_context ""
  [[ ! -f "${TEST_TMPDIR}/k" ]]
}

@test "cluster.sh - kube_apply_context switches via kubectl" {
  _kubectl() { printf '%s\n' "$*" > "${TEST_TMPDIR}/k"; }
  kube_apply_context "dev-ctx"
  grep -q "config use-context dev-ctx" "${TEST_TMPDIR}/k"
}

@test "cluster.sh - kube_apply_namespace is a no-op for an empty name" {
  _kubectl() { echo "called" > "${TEST_TMPDIR}/k"; }
  ! kube_apply_namespace ""
  [[ ! -f "${TEST_TMPDIR}/k" ]]
}

@test "cluster.sh - kube_apply_namespace switches via kubectl" {
  _kubectl() { printf '%s\n' "$*" > "${TEST_TMPDIR}/k"; }
  kube_apply_namespace "web"
  grep -q "config set-context --current --namespace web" "${TEST_TMPDIR}/k"
}

@test "cluster.sh - kube_probe_all does nothing when all probes are off" {
  _kubectl() { echo "called" > "${TEST_TMPDIR}/k"; }
  kube_probe_all
  [[ -z "$(cache_get reach)" ]]
  [[ -z "$(cache_get nodes)" ]]
  [[ -z "$(cache_get pods)" ]]
  [[ ! -f "${TEST_TMPDIR}/k" ]]
}

@test "cluster.sh - kube_probe_all caches reach up" {
  set_tmux_option "@kube_revamped_probe_reach" "1"
  _kubectl() { return 0; }
  kube_probe_all
  [[ "$(cache_get reach)" == "up" ]]
}

@test "cluster.sh - kube_probe_all caches reach down" {
  set_tmux_option "@kube_revamped_probe_reach" "1"
  _kubectl() { return 1; }
  kube_probe_all
  [[ "$(cache_get reach)" == "down" ]]
}

@test "cluster.sh - kube_probe_all caches the node state" {
  set_tmux_option "@kube_revamped_probe_nodes" "1"
  _kubectl() { printf 'n1 Ready a b c\nn2 NotReady a b c\n'; }
  kube_probe_all
  [[ "$(cache_get nodes)" == "1/2" ]]
}

@test "cluster.sh - kube_probe_all caches the pod state" {
  set_tmux_option "@kube_revamped_probe_pods" "1"
  _kubectl() { printf 'p1 0/1 CrashLoopBackOff 3 1m\n'; }
  kube_probe_all
  [[ "$(cache_get pods)" == "1" ]]
}

@test "cluster.sh - kube_health_segment is empty when no probe is on" {
  run kube_health_segment
  [[ -z "${output}" ]]
}

@test "cluster.sh - kube_health_segment shows reach up" {
  set_tmux_option "@kube_revamped_probe_reach" "1"
  cache_set reach "up"
  run kube_health_segment
  [[ "${output}" == " #[fg=green]o#[default]" ]]
}

@test "cluster.sh - kube_health_segment shows reach down" {
  set_tmux_option "@kube_revamped_probe_reach" "1"
  cache_set reach "down"
  run kube_health_segment
  [[ "${output}" == " #[fg=red]x#[default]" ]]
}

@test "cluster.sh - kube_health_segment skips reach when unknown" {
  set_tmux_option "@kube_revamped_probe_reach" "1"
  run kube_health_segment
  [[ -z "${output}" ]]
}

@test "cluster.sh - kube_health_segment shows nodes all ready in green" {
  set_tmux_option "@kube_revamped_probe_nodes" "1"
  cache_set nodes "3/3"
  run kube_health_segment
  [[ "${output}" == " #[fg=green]3/3#[default]" ]]
}

@test "cluster.sh - kube_health_segment warns on degraded nodes" {
  set_tmux_option "@kube_revamped_probe_nodes" "1"
  cache_set nodes "2/3"
  run kube_health_segment
  [[ "${output}" == " #[fg=yellow]2/3#[default]" ]]
}

@test "cluster.sh - kube_health_segment skips nodes when empty" {
  set_tmux_option "@kube_revamped_probe_nodes" "1"
  run kube_health_segment
  [[ -z "${output}" ]]
}

@test "cluster.sh - kube_health_segment warns on bad pods" {
  set_tmux_option "@kube_revamped_probe_pods" "1"
  cache_set pods "2"
  run kube_health_segment
  [[ "${output}" == " #[fg=yellow]!2#[default]" ]]
}

@test "cluster.sh - kube_health_segment hides a zero pod count" {
  set_tmux_option "@kube_revamped_probe_pods" "1"
  cache_set pods "0"
  run kube_health_segment
  [[ -z "${output}" ]]
}

@test "cluster.sh - kube_health_segment skips pods when empty" {
  set_tmux_option "@kube_revamped_probe_pods" "1"
  run kube_health_segment
  [[ -z "${output}" ]]
}
