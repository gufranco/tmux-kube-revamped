# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
