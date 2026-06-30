# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-29

### Added

- Context switcher and namespace switcher in the bar, opened with configurable
  keys via display-menu. The context list is read from the kubeconfig; the
  namespace list comes from the cluster only when you open that menu.
- k9s popup pinned to the current context and namespace, gated on tmux 3.2+.
- Full KUBECONFIG support: every file in the colon-separated list is read and
  merged, with the last current-context winning, so the shown context can no
  longer be wrong when KUBECONFIG names more than one file.
- Dangling-context warning: a current-context absent from the merged kubeconfig
  is flagged with a warning color and marker instead of a misleading name.
- Optional cluster + user in the segment, with a prod-context warning color.
- Opt-in async health badges fed by a detached worker: a reachability dot, a
  node-ready badge, and a non-running pod count. Every cluster call runs behind
  a seam and only when its probe is enabled, so the default plugin never forks
  kubectl and the render never blocks.
- A `doctor` report listing detected tools, kubeconfig readability, and whether
  the current context is dangling.

## [1.0.1] - 2026-06-23

### Changed

- Reviewed the upstream `jonmosco/kube-tmux` issues. Output stays clean in every
  state: an empty or absent current context renders nothing rather than garbled
  text (#22). The default segment color is a named color, so it survives the
  tmux 3.7 format-expansion change unharmed. No code change needed.

## [1.0.0] - 2026-06-22

### Added

- Current Kubernetes context and namespace in the status bar via #{kube},
  #{kube_context}, and #{kube_namespace}.
- Parses ~/.kube/config (honoring $KUBECONFIG) directly, so it needs no kubectl
  and never forks a process on render.
- Async cache in tmux server options with a detached background worker; the
  render never blocks and no temp file is written.
- Configurable icon, color, namespace visibility, refresh interval, and a
  hide-default toggle.
