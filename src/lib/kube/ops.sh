#!/usr/bin/env bash
#
# ops.sh: interactive operations: context and namespace switchers, the k9s popup,
# the key bindings that drive them, and the doctor report.
#
# Every tmux action flows through the _tmux seam and every cluster call through
# the _kubectl seam (in cluster.sh), so the menus, popup, and bindings are
# validated without a live tmux and without touching a cluster.

[[ -n "${_KUBE_REVAMPED_OPS_LOADED:-}" ]] && return 0
_KUBE_REVAMPED_OPS_LOADED=1

_KUBE_OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_KUBE_OPS_DIR}/../tmux/tmux-ops.sh"
# shellcheck source=/dev/null
source "${_KUBE_OPS_DIR}/../utils/cache.sh"
# shellcheck source=/dev/null
source "${_KUBE_OPS_DIR}/../utils/has-command.sh"
# shellcheck source=/dev/null
source "${_KUBE_OPS_DIR}/kube.sh"
# shellcheck source=/dev/null
source "${_KUBE_OPS_DIR}/cluster.sh"

# _tmux ARGS... -> the single seam every interactive tmux command flows through.
# Tests replace it to capture the command instead of running a live tmux.
_tmux() {
  tmux "$@"
}

# kube_parse_version TEXT -> major.minor from `tmux -V`, handling 3.4a and next-3.5.
kube_parse_version() {
  printf '%s\n' "${1}" | sed -En 's/^tmux[ -]([a-z]+-)?([0-9]+\.[0-9]+).*/\2/p'
}

# kube_version_ge HAVE WANT -> 0 when HAVE is greater than or equal to WANT.
kube_version_ge() {
  [[ -n "${1}" && -n "${2}" ]] || return 1
  [ "$(printf '%s\n%s\n' "${2}" "${1}" | sort -V | head -n1)" = "${2}" ]
}

# _kube_tmux_version_string -> raw `tmux -V`. Host-probe seam; tests override it.
_kube_tmux_version_string() {
  tmux -V 2>/dev/null
}

kube_tmux_version() {
  kube_parse_version "$(_kube_tmux_version_string)"
}

# kube_menu_context SELF -> a display-menu of every kubeconfig context; selecting
# one switches to it. The context list comes from the kubeconfig, no cluster.
kube_menu_context() {
  local self="${1}" yaml name
  yaml="$(_kube_config_text)"
  local args=(display-menu -T "Context")
  while IFS= read -r name; do
    args+=("${name}" "" "run-shell \"${self} use-context ${name}\"")
  done < <(kube_list_contexts "${yaml}")
  [[ ${#args[@]} -le 3 ]] && return 0
  _tmux "${args[@]}"
}

# kube_menu_namespace SELF -> a display-menu of the cluster's namespaces; selecting
# one switches the current context to it. Reaches the cluster through _kubectl, so
# it runs only on the keypress, never on the hot path.
kube_menu_namespace() {
  local self="${1}" name
  local args=(display-menu -T "Namespace")
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    args+=("${name}" "" "run-shell \"${self} use-namespace ${name}\"")
  done < <(kube_list_namespaces)
  [[ ${#args[@]} -le 3 ]] && return 0
  _tmux "${args[@]}"
}

# kube_popup -> open k9s in a display-popup pinned to the current context and
# namespace. Gated on tmux 3.2+, the floor for display-popup; older tmux is a
# no-op. Reads the cached context, so it never parses the kubeconfig on keypress.
kube_popup() {
  local cached ctx ns width height cmd full
  kube_version_ge "$(kube_tmux_version)" 3.2 || return 0
  cached="$(cache_get value)"
  ns=""
  [[ "${cached}" == *"|"* ]] && ns="${cached#*|}"
  ctx="${cached%%|*}"
  [[ -z "${ctx}" ]] && return 0
  width="$(get_tmux_option "@kube_revamped_popup_width" "80%")"
  height="$(get_tmux_option "@kube_revamped_popup_height" "80%")"
  cmd="$(get_tmux_option "@kube_revamped_popup_command" "k9s")"
  full="${cmd} --context ${ctx}"
  [[ -n "${ns}" ]] && full="${full} --namespace ${ns}"
  _tmux display-popup -E -w "${width}" -h "${height}" "${full}"
}

# kube_apply_keys SELF -> bind the configured switcher and popup keys. Every key
# defaults to empty, so nothing is bound unless the user opts in, and no default
# keybinding is ever stolen.
kube_apply_keys() {
  local self="${1}" k_ctx k_ns k_pop
  k_ctx="$(get_tmux_option "@kube_revamped_menu_context_key" "")"
  k_ns="$(get_tmux_option "@kube_revamped_menu_namespace_key" "")"
  k_pop="$(get_tmux_option "@kube_revamped_popup_key" "")"
  [[ -n "${k_ctx}" ]] && _tmux bind-key "${k_ctx}" run-shell "${self} menu-context"
  [[ -n "${k_ns}" ]] && _tmux bind-key "${k_ns}" run-shell "${self} menu-namespace"
  [[ -n "${k_pop}" ]] && _tmux bind-key "${k_pop}" run-shell "${self} popup"
  return 0
}

# kube_doctor -> a capability report: which tools are present, which kubeconfig
# files are readable, and whether the current context is dangling.
kube_doctor() {
  local yaml ctx f
  echo "tmux-kube-revamped doctor"
  if has_command kubectl; then
    echo "kubectl: found"
  else
    echo "kubectl: not found (not required for context/namespace)"
  fi
  if has_command k9s; then
    echo "k9s: found"
  else
    echo "k9s: not found (popup disabled)"
  fi
  echo "kubeconfig files:"
  while IFS= read -r f; do
    if [[ -r "${f}" ]]; then
      echo "  ${f} (readable)"
    else
      echo "  ${f} (missing)"
    fi
  done < <(_kube_config_files)
  yaml="$(_kube_config_text)"
  ctx="$(kube_current_context "${yaml}")"
  if [[ -z "${ctx}" ]]; then
    echo "current-context: (none)"
  elif kube_context_exists "${yaml}" "${ctx}"; then
    echo "current-context: ${ctx}"
  else
    echo "current-context: ${ctx} (DANGLING: not in kubeconfig)"
  fi
}

export -f _tmux
export -f kube_parse_version
export -f kube_version_ge
export -f _kube_tmux_version_string
export -f kube_tmux_version
export -f kube_menu_context
export -f kube_menu_namespace
export -f kube_popup
export -f kube_apply_keys
export -f kube_doctor
