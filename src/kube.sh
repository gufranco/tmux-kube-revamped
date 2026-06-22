#!/usr/bin/env bash
#
# kube.sh: command dispatcher for tmux-kube-revamped.
#
# Usage: kube.sh kube | context | namespace | refresh
#
# The kubeconfig read runs in a detached background worker and the result is
# cached in tmux server user-options, so the status line never blocks and no temp
# file is touched.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export CACHE_PREFIX="kube_revamped"

# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/tmux/tmux-ops.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/utils/cache.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/kube/kube.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/kube/render.sh"

# kube_max_age -> seconds a cached context stays fresh.
kube_max_age() {
  local s
  s=$(get_tmux_option "@kube_revamped_interval" "10")
  [[ "${s}" =~ ^[0-9]+$ ]] || s=10
  echo "${s}"
}

# kube_refresh -> the cache worker: read the kubeconfig once and store the
# context and namespace as "context|namespace", or empty when not in a cluster.
kube_refresh() {
  local yaml ctx ns
  yaml="$(_kube_config_text)"
  ctx="$(kube_current_context "${yaml}")"
  if [[ -z "${ctx}" ]]; then
    cache_set value ""
    return 0
  fi
  ns="$(kube_namespace_for "${yaml}" "${ctx}")"
  cache_set value "${ctx}|${ns}"
}

# kube_render CACHED -> the formatted segment from a "context|namespace" value.
kube_render() {
  local cached="${1}" ctx ns
  [[ -z "${cached}" ]] && return 0
  ctx="${cached%%|*}"
  ns=""
  [[ "${cached}" == *"|"* ]] && ns="${cached#*|}"
  kube_render_segment "${ctx}" "${ns}"
}

main() {
  local cmd="${1:-}"

  if [[ "${cmd}" == "refresh" ]]; then
    kube_refresh
    return 0
  fi

  cache_refresh_if_stale value "$(kube_max_age)" kube_refresh

  local cached
  cached="$(cache_get value)"
  case "${cmd}" in
    kube)      kube_render "${cached}" ;;
    context)   echo "${cached%%|*}" ;;
    namespace) [[ "${cached}" == *"|"* ]] && echo "${cached#*|}" ;;
    *)         return 0 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
