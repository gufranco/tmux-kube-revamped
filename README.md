<div align="center">

<h1>tmux-kube-revamped</h1>

**Current Kubernetes context and namespace in your tmux status bar, async, kubectl-free, never blocking.**

[![Tests](https://github.com/gufranco/tmux-kube-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/gufranco/tmux-kube-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

**3** placeholders · **no kubectl required** · **tmux 1.9 to 3.5** · **63** tests · **95%+** coverage

Shows the active Kubernetes context and namespace, read straight from your kubeconfig. It parses `~/.kube/config` directly, so it works without `kubectl` installed and never forks a process on the hot path. The read runs in a detached background worker and the result is cached in tmux server options, so the status line never waits, and no temp file is ever written.

Built from [tmux-plugin-template](https://github.com/gufranco/tmux-plugin-template).

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
set -g @plugin 'gufranco/tmux-kube-revamped'
```

Then press `prefix + I`, and put `#{kube}` somewhere in `status-left` or `status-right`.

Manual install:

```bash
git clone https://github.com/gufranco/tmux-kube-revamped ~/.tmux/plugins/tmux-kube-revamped
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

The segment is empty when there is no current context, so it disappears when you are not pointed at a cluster.

## Compatibility

Works on every tmux version TPM supports, 1.9 and up, on Linux (x86_64 and arm64) and macOS (Intel and Apple Silicon). It honors `$KUBECONFIG` (the first file in a colon-separated list) and falls back to `~/.kube/config`.

## Development

```bash
make test    # bats suite
make lint    # shellcheck
make coverage  # kcov line coverage on Linux
```

The kubeconfig parsing lives in [`src/lib/kube/kube.sh`](src/lib/kube/kube.sh) as pure, seam-backed helpers, validated against fixtures with no real cluster.

## License

[MIT](LICENSE), copyright Gustavo Franco.
