#!/usr/bin/env bash
#
# kube.sh: read the current Kubernetes context and namespace from the kubeconfig.
#
# Parsing is pure. The file read sits behind a seam the tests override, so no real
# kubeconfig is touched under test. Reading the config directly means the plugin
# works without kubectl installed and never forks a kubectl process on refresh.

[[ -n "${_KUBE_REVAMPED_LOADED:-}" ]] && return 0
_KUBE_REVAMPED_LOADED=1

# kube_current_context YAML -> the value of the top-level current-context key,
# empty when absent. Quotes around the value are stripped.
kube_current_context() {
  printf '%s\n' "${1}" | awk '/^current-context:/ { v=$2; gsub(/"/, "", v); print v; exit }'
}

# kube_namespace_for YAML CONTEXT -> the namespace of CONTEXT, "default" when the
# context has none, empty when the context is not found. Reads the kubectl layout
# where each contexts entry has a context block (with namespace) then a name.
kube_namespace_for() {
  printf '%s\n' "${1}" | awk -v want="${2}" '/^contexts:/{inc=1;next} inc&&/^[A-Za-z]/{inc=0} !inc{next} /^[[:space:]]*-/{ns="";name=""} /namespace:/{ns=$2;gsub(/"/,"",ns)} /name:/{name=$2;gsub(/"/,"",name);if(name==want){print(ns==""?"default":ns);exit}}'
}

# Host-probe seam. Tests override this. Honors KUBECONFIG (first file in a colon
# separated list), else ~/.kube/config.
_kube_config_text() {
  local f="${KUBECONFIG%%:*}"
  [[ -z "${f}" ]] && f="${HOME}/.kube/config"
  cat "${f}" 2>/dev/null
}

export -f kube_current_context
export -f kube_namespace_for
export -f _kube_config_text
