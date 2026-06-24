# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
