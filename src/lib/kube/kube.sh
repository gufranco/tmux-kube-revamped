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
# empty when absent. Quotes around the value are stripped. When the merged text
# holds several current-context lines (one per KUBECONFIG file), the last
# non-empty value wins, matching how a colon-separated KUBECONFIG is resolved.
kube_current_context() {
  printf '%s\n' "${1}" | awk '/^current-context:/ { v=$2; gsub(/"/, "", v); if (v != "") last=v } END { print last }'
}

# kube_namespace_for YAML CONTEXT -> the namespace of CONTEXT, "default" when the
# context has none, empty when the context is not found. Reads the kubectl layout
# where each contexts entry has a context block (with namespace) then a name.
kube_namespace_for() {
  printf '%s\n' "${1}" | awk -v want="${2}" '/^contexts:/{inc=1;next} inc&&/^[A-Za-z]/{inc=0} !inc{next} /^[[:space:]]*-/{ns="";name=""} /namespace:/{ns=$2;gsub(/"/,"",ns)} /name:/{name=$2;gsub(/"/,"",name);if(name==want){print(ns==""?"default":ns);exit}}'
}

# kube_cluster_for YAML CONTEXT -> the cluster name bound to CONTEXT, empty when
# the context is not found or declares no cluster.
kube_cluster_for() {
  printf '%s\n' "${1}" | awk -v want="${2}" '/^contexts:/{inc=1;next} inc&&/^[A-Za-z]/{inc=0} !inc{next} /^[[:space:]]*-/{cl="";name=""} /cluster:/{cl=$2;gsub(/"/,"",cl)} /name:/{name=$2;gsub(/"/,"",name);if(name==want){print cl;exit}}'
}

# kube_user_for YAML CONTEXT -> the user name bound to CONTEXT, empty when the
# context is not found or declares no user.
kube_user_for() {
  printf '%s\n' "${1}" | awk -v want="${2}" '/^contexts:/{inc=1;next} inc&&/^[A-Za-z]/{inc=0} !inc{next} /^[[:space:]]*-/{us="";name=""} /user:/{us=$2;gsub(/"/,"",us)} /name:/{name=$2;gsub(/"/,"",name);if(name==want){print us;exit}}'
}

# kube_list_contexts YAML -> every context name, one per line, in file order.
kube_list_contexts() {
  printf '%s\n' "${1}" | awk '/^contexts:/{inc=1;next} inc&&/^[A-Za-z]/{inc=0} !inc{next} /name:/{n=$2;gsub(/"/,"",n);if(n!="")print n}'
}

# kube_context_exists YAML NAME -> 0 when NAME is one of the kubeconfig contexts.
# A current-context that fails this check is dangling: it points at a context the
# merged kubeconfig no longer defines, the classic stale-context-after-VPN case.
kube_context_exists() {
  [[ -z "${2}" ]] && return 1
  kube_list_contexts "${1}" | grep -qxF -- "${2}"
}

# _kube_config_files -> one kubeconfig path per line. Honors the full KUBECONFIG
# colon-separated list, falling back to ~/.kube/config when it is unset. This is
# a seam: tests point it at fixture files instead of a real kubeconfig.
_kube_config_files() {
  local list="${KUBECONFIG:-${HOME}/.kube/config}"
  local f
  local IFS=':'
  for f in ${list}; do
    [[ -n "${f}" ]] && printf '%s\n' "${f}"
  done
}

# _kube_config_text -> the merged text of every kubeconfig file, newline-joined so
# a context block in one file never runs into the next. Host-probe seam: tests
# override it. Reading every file means a context defined only in a later
# KUBECONFIG entry is still seen, instead of silently showing the first file.
_kube_config_text() {
  local f
  while IFS= read -r f; do
    cat "${f}" 2>/dev/null
    printf '\n'
  done < <(_kube_config_files)
}

export -f kube_current_context
export -f kube_namespace_for
export -f kube_cluster_for
export -f kube_user_for
export -f kube_list_contexts
export -f kube_context_exists
export -f _kube_config_files
export -f _kube_config_text
