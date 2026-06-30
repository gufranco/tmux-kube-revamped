<div align="center">

<h1>tmux-kube-revamped</h1>

**Current Kubernetes context and namespace in your tmux status bar, async, kubectl-free, never blocking.**

[![Tests](https://github.com/tmux-revamped/tmux-kube-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-kube-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](CHANGELOG.md)

</div>

**3** placeholders · **2** switchers · **k9s popup** · **no kubectl required** · **tmux 1.9 to 3.5** · **164** tests · **95%+** coverage

Shows the active Kubernetes context and namespace, read straight from your kubeconfig. It parses `~/.kube/config` directly, so it works without `kubectl` installed and never forks a process on the hot path. The read runs in a detached background worker and the result is cached in tmux server options, so the status line never waits, and no temp file is ever written.

Built from [tmux-plugin-template](https://github.com/tmux-revamped/tmux-plugin-template).

<table>
<tr>
<td><strong>kubectl-free</strong><br>Reads the kubeconfig directly. No <code>kubectl</code> fork on every render, no Go process spinup.</td>
<td><strong>Never blocks</strong><br>A background worker refreshes the cache; the render reads it instantly.</td>
</tr>
<tr>
<td><strong>No temp files</strong><br>State lives in tmux server options, nothing to clean up, no <code>/tmp</code> collisions.</td>
<td><strong>Configurable</strong><br>Icon, color, namespace visibility, refresh interval, and a hide-default toggle.</td>
</tr>
</table>

## Placeholders

| Placeholder | Output |
|-------------|--------|
| `#{kube}` | the styled segment, for example `prod-ctx:web` |
| `#{kube_context}` | the current context name only |
| `#{kube_namespace}` | the current namespace only |

```tmux
set -g status-right '#{kube} | %H:%M'
```

## Install

With [TPM](https://github.com/tmux-plugins/tpm), add to `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-revamped/tmux-kube-revamped'
```

Then press `prefix + I`, and put `#{kube}` somewhere in `status-left` or `status-right`.

Manual install:

```bash
git clone https://github.com/tmux-revamped/tmux-kube-revamped ~/.tmux/plugins/tmux-kube-revamped
run-shell ~/.tmux/plugins/tmux-kube-revamped/kube-revamped.tmux
```

## Configuration

| Option | Default | Meaning |
|--------|---------|---------|
| `@kube_revamped_interval` | `10` | seconds a cached context stays fresh |
| `@kube_revamped_icon` | empty | a glyph shown before the context, for example a Nerd Font kubernetes mark |
| `@kube_revamped_color` | `#[fg=blue]` | the segment color |
| `@kube_revamped_show_namespace` | `1` | set to `0` to show only the context, not `context:namespace` |
| `@kube_revamped_hide_default` | `0` | set to `1` to hide the segment when the context is `default` |
| `@kube_revamped_show_cluster` | `0` | set to `1` to append `@cluster` to the context |
| `@kube_revamped_show_user` | `0` | set to `1` to append ` (user)` to the segment |
| `@kube_revamped_prod_pattern` | empty | substring that marks a context as production, for example `prod` |
| `@kube_revamped_prod_color` | `#[fg=red]` | the color used when the context matches the prod pattern |
| `@kube_revamped_warn_color` | `#[fg=yellow]` | the color for a dangling context and the health badges |
| `@kube_revamped_warn_icon` | `?` | the marker shown after a dangling context |
| `@kube_revamped_menu_context_key` | empty | key bound to the context switcher, for example `C-k` |
| `@kube_revamped_menu_namespace_key` | empty | key bound to the namespace switcher |
| `@kube_revamped_popup_key` | empty | key bound to the k9s popup |
| `@kube_revamped_popup_command` | `k9s` | the command run in the popup |
| `@kube_revamped_popup_width` | `80%` | popup width |
| `@kube_revamped_popup_height` | `80%` | popup height |
| `@kube_revamped_probe_reach` | `0` | set to `1` for a cluster reachability dot (async, opt-in) |
| `@kube_revamped_probe_nodes` | `0` | set to `1` for a node-ready badge (async, opt-in) |
| `@kube_revamped_probe_pods` | `0` | set to `1` for a non-running pod count (async, opt-in) |

The segment is empty when there is no current context, so it disappears when you are not pointed at a cluster.

## Switchers, popup, and health

Bind a key to switch context or namespace from the bar, or to open k9s pinned to
the current context and namespace. Every key defaults to empty, so nothing is
bound unless you opt in.

```tmux
set -g @kube_revamped_menu_context_key 'C-k'
set -g @kube_revamped_menu_namespace_key 'C-n'
set -g @kube_revamped_popup_key 'K'
```

The context switcher reads the kubeconfig directly. The namespace switcher and the
health badges talk to the cluster, so they are off by default and run through a
detached worker. Turn the badges on per signal:

```tmux
set -g @kube_revamped_probe_reach '1'
set -g @kube_revamped_probe_nodes '1'
set -g @kube_revamped_probe_pods '1'
```

The popup needs `k9s` and tmux 3.2+. The switchers and namespace probes need
`kubectl`. Run `src/kube.sh doctor` to see what was detected on this host.

## Compatibility

Works on every tmux version TPM supports, 1.9 and up, on Linux (x86_64 and arm64) and macOS (Intel and Apple Silicon). It reads every file in `$KUBECONFIG` (the full colon-separated list, last current-context winning) and falls back to `~/.kube/config`.

## Development

```bash
make test    # bats suite
make lint    # shellcheck
make coverage  # kcov line coverage on Linux
```

The kubeconfig parsing lives in [`src/lib/kube/kube.sh`](src/lib/kube/kube.sh) as pure, seam-backed helpers, validated against fixtures with no real cluster.

## License

[MIT](LICENSE), copyright Gustavo Franco.
