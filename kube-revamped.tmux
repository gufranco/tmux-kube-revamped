#!/usr/bin/env bash
#
# kube-revamped.tmux: TPM entry point.
#
# Replaces the #{kube*} placeholders in status-left and status-right with calls to
# the dispatcher. The kubeconfig read runs in a background worker, so the render
# never waits.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_CMD="${CURRENT_DIR}/src/kube.sh"

placeholders=(
  "\#{kube_context}"
  "\#{kube_namespace}"
  "\#{kube}"
)

commands=(
  "#(${KUBE_CMD} context)"
  "#(${KUBE_CMD} namespace)"
  "#(${KUBE_CMD} kube)"
)

interpolate() {
  local value="${1}"
  for (( i = 0; i < ${#placeholders[@]}; i++ )); do
    value="${value//${placeholders[i]}/${commands[i]}}"
  done
  echo "${value}"
}

update_option() {
  local option="${1}" current
  current=$(tmux show-option -gqv "${option}")
  tmux set-option -gq "${option}" "$(interpolate "${current}")"
}

chmod +x "${KUBE_CMD}" 2>/dev/null || true

update_option "status-left"
update_option "status-right"

# Bind the opt-in context/namespace switchers and the k9s popup. Each key
# defaults to empty, so this binds nothing unless the user opts in.
"${KUBE_CMD}" bind-keys 2>/dev/null || true
