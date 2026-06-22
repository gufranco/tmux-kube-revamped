#!/usr/bin/env bash
#
# render.sh: format the Kubernetes context and namespace into a status segment.

[[ -n "${_KUBE_REVAMPED_RENDER_LOADED:-}" ]] && return 0
_KUBE_REVAMPED_RENDER_LOADED=1

_KUBE_RENDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_KUBE_RENDER_DIR}/../tmux/tmux-ops.sh"

_KUBE_RESET="#[default]"

# kube_render_segment CONTEXT NAMESPACE -> "<color><icon> <context>[:<namespace>]
# <reset>". Empty when there is no context, or when hide_default is on and the
# context is "default".
kube_render_segment() {
  local ctx="${1}" ns="${2}" color icon out
  [[ -z "${ctx}" ]] && return 0
  [[ "$(get_tmux_option "@kube_revamped_hide_default" "0")" == "1" && "${ctx}" == "default" ]] && return 0
  color=$(get_tmux_option "@kube_revamped_color" "#[fg=blue]")
  icon=$(get_tmux_option "@kube_revamped_icon" "")
  out="${ctx}"
  if [[ "$(get_tmux_option "@kube_revamped_show_namespace" "1")" == "1" && -n "${ns}" ]]; then
    out="${out}:${ns}"
  fi
  if [[ -n "${icon}" ]]; then
    echo "${color}${icon} ${out}${_KUBE_RESET}"
  else
    echo "${color}${out}${_KUBE_RESET}"
  fi
}

export -f kube_render_segment
