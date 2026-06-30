#!/usr/bin/env bash
#
# render.sh: format the Kubernetes context and namespace into a status segment.

[[ -n "${_KUBE_REVAMPED_RENDER_LOADED:-}" ]] && return 0
_KUBE_REVAMPED_RENDER_LOADED=1

_KUBE_RENDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_KUBE_RENDER_DIR}/../tmux/tmux-ops.sh"

_KUBE_RESET="#[default]"

# kube_render_segment CONTEXT NAMESPACE [DANGLING] [CLUSTER] [USER] ->
# "<color><icon> <context>[@cluster][:namespace][ (user)][ <warn>]<reset>".
# Empty when there is no context, or when hide_default is on and the context is
# "default". The color turns to the warn color when the context is dangling, and
# to the prod color when the context matches the configured prod pattern.
kube_render_segment() {
  local ctx="${1}" ns="${2}" dangling="${3:-}" cluster="${4:-}" user="${5:-}"
  local color icon out prod_pattern marker
  [[ -z "${ctx}" ]] && return 0
  if [[ "$(get_tmux_option "@kube_revamped_hide_default" "0")" == "1" && "${ctx}" == "default" ]]; then
    return 0
  fi

  color=$(get_tmux_option "@kube_revamped_color" "#[fg=blue]")
  prod_pattern=$(get_tmux_option "@kube_revamped_prod_pattern" "")
  if [[ -n "${prod_pattern}" && "${ctx}" == *"${prod_pattern}"* ]]; then
    color=$(get_tmux_option "@kube_revamped_prod_color" "#[fg=red]")
  fi
  icon=$(get_tmux_option "@kube_revamped_icon" "")

  out="${ctx}"
  if [[ "$(get_tmux_option "@kube_revamped_show_cluster" "0")" == "1" && -n "${cluster}" ]]; then
    out="${out}@${cluster}"
  fi
  if [[ "$(get_tmux_option "@kube_revamped_show_namespace" "1")" == "1" && -n "${ns}" ]]; then
    out="${out}:${ns}"
  fi
  if [[ "$(get_tmux_option "@kube_revamped_show_user" "0")" == "1" && -n "${user}" ]]; then
    out="${out} (${user})"
  fi
  if [[ "${dangling}" == "1" ]]; then
    color=$(get_tmux_option "@kube_revamped_warn_color" "#[fg=yellow]")
    marker=$(get_tmux_option "@kube_revamped_warn_icon" "?")
    out="${out} ${marker}"
  fi

  if [[ -n "${icon}" ]]; then
    echo "${color}${icon} ${out}${_KUBE_RESET}"
  else
    echo "${color}${out}${_KUBE_RESET}"
  fi
}

export -f kube_render_segment
