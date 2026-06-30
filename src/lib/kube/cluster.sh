#!/usr/bin/env bash
#
# cluster.sh: opt-in cluster probes and kubeconfig mutations.
#
# Every line in this file that can reach a real cluster goes through the _kubectl
# seam, which the tests override. Nothing here runs unless the matching
# @kube_revamped_probe_* option is on, so the default plugin never forks kubectl
# and never touches a cluster. The probes run in the detached worker, so even when
# enabled they never block the status render.

[[ -n "${_KUBE_REVAMPED_CLUSTER_LOADED:-}" ]] && return 0
_KUBE_REVAMPED_CLUSTER_LOADED=1

_KUBE_CLUSTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_KUBE_CLUSTER_DIR}/../tmux/tmux-ops.sh"
# shellcheck source=/dev/null
source "${_KUBE_CLUSTER_DIR}/../utils/cache.sh"

# _kubectl ARGS... -> the single seam every cluster call flows through. The tests
# replace this with a stub, so no command ever reaches a real cluster under test.
_kubectl() {
  kubectl "$@"
}

# kube_reach_ok -> 0 when the current cluster answers. A short request timeout
# keeps a dead VPN from hanging the worker.
kube_reach_ok() {
  _kubectl cluster-info --request-timeout=2 >/dev/null 2>&1
}

# kube_parse_nodes TEXT -> "ready/total" from `kubectl get nodes --no-headers`.
kube_parse_nodes() {
  printf '%s\n' "${1}" | awk 'NF{t++; if($2=="Ready")r++} END{print r+0"/"t+0}'
}

# kube_nodes_state -> "ready/total" for the current context, empty on failure.
kube_nodes_state() {
  local out
  out="$(_kubectl get nodes --no-headers --request-timeout=2 2>/dev/null)" || return 0
  [[ -z "${out}" ]] && return 0
  kube_parse_nodes "${out}"
}

# kube_parse_pods TEXT -> count of pods whose STATUS is neither Running nor
# Completed, from `kubectl get pods --no-headers`. Crashloops and pending pods.
kube_parse_pods() {
  printf '%s\n' "${1}" | awk 'NF{ if($3!="Running" && $3!="Completed") b++ } END{print b+0}'
}

# kube_pods_state -> bad-pod count for the current namespace, empty on failure.
kube_pods_state() {
  local out
  out="$(_kubectl get pods --no-headers --request-timeout=2 2>/dev/null)" || return 0
  [[ -z "${out}" ]] && return 0
  kube_parse_pods "${out}"
}

# kube_list_namespaces -> namespace names for the current cluster, one per line.
# Used by the namespace switcher menu. Needs the cluster, so it is invoked only
# when the user opens the menu, never on the hot path.
kube_list_namespaces() {
  _kubectl get namespaces -o name --request-timeout=2 2>/dev/null | sed 's#^namespace/##'
}

# kube_apply_context NAME -> switch the kubeconfig current-context (replaces a
# kubectx round-trip). Mutates the kubeconfig file via kubectl, behind the seam.
kube_apply_context() {
  [[ -z "${1}" ]] && return 1
  _kubectl config use-context "${1}" >/dev/null 2>&1
}

# kube_apply_namespace NAME -> set the namespace of the current context (replaces
# kubens). Mutates the kubeconfig file via kubectl, behind the seam.
kube_apply_namespace() {
  [[ -z "${1}" ]] && return 1
  _kubectl config set-context --current --namespace "${1}" >/dev/null 2>&1
}

# kube_probe_all -> run each enabled probe and cache its result. Called from the
# worker. Each probe is gated on its own option and defaults off.
kube_probe_all() {
  if [[ "$(get_tmux_option "@kube_revamped_probe_reach" "0")" == "1" ]]; then
    if kube_reach_ok; then
      cache_set reach "up"
    else
      cache_set reach "down"
    fi
  fi
  if [[ "$(get_tmux_option "@kube_revamped_probe_nodes" "0")" == "1" ]]; then
    cache_set nodes "$(kube_nodes_state)"
  fi
  if [[ "$(get_tmux_option "@kube_revamped_probe_pods" "0")" == "1" ]]; then
    cache_set pods "$(kube_pods_state)"
  fi
}

# kube_health_segment -> the trailing health badges built from cached probe
# results: a reachability dot, a node-ready badge, and a bad-pod count. Empty
# when no probe is enabled. Reads only cache and options, never the cluster.
kube_health_segment() {
  local out="" reach nodes pods warn ndr ndt
  warn="$(get_tmux_option "@kube_revamped_warn_color" "#[fg=yellow]")"

  if [[ "$(get_tmux_option "@kube_revamped_probe_reach" "0")" == "1" ]]; then
    reach="$(cache_get reach)"
    if [[ "${reach}" == "up" ]]; then
      out="${out} #[fg=green]o#[default]"
    elif [[ "${reach}" == "down" ]]; then
      out="${out} #[fg=red]x#[default]"
    fi
  fi

  if [[ "$(get_tmux_option "@kube_revamped_probe_nodes" "0")" == "1" ]]; then
    nodes="$(cache_get nodes)"
    if [[ -n "${nodes}" ]]; then
      ndr="${nodes%%/*}"
      ndt="${nodes#*/}"
      if [[ "${ndr}" == "${ndt}" ]]; then
        out="${out} #[fg=green]${nodes}#[default]"
      else
        out="${out} ${warn}${nodes}#[default]"
      fi
    fi
  fi

  if [[ "$(get_tmux_option "@kube_revamped_probe_pods" "0")" == "1" ]]; then
    pods="$(cache_get pods)"
    if [[ -n "${pods}" && "${pods}" != "0" ]]; then
      out="${out} ${warn}!${pods}#[default]"
    fi
  fi

  printf '%s' "${out}"
}

export -f _kubectl
export -f kube_reach_ok
export -f kube_parse_nodes
export -f kube_nodes_state
export -f kube_parse_pods
export -f kube_pods_state
export -f kube_list_namespaces
export -f kube_apply_context
export -f kube_apply_namespace
export -f kube_probe_all
export -f kube_health_segment
