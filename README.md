# tmx — tmux session picker

Interactive tmux session manager using `fzf` with live preview, hidden sessions,
session rename, session kill, and vim-style navigation.

## Requirements

- tmux 2.6+
- fzf 0.21+
- POSIX `sh` (works on macOS, Linux, BSD)

## Install

```bash
# macOS
brew install tmux fzf

# Linux (apt)
sudo apt install tmux fzf

# Install tmx
cp tmx ~/bin/tmx && chmod +x ~/bin/tmx
```

Ensure `~/bin` is in your `PATH`.

## Usage

```bash
tmx
```

### Keybindings

| Key | Action |
|-----|--------|
| `j` / `k` | Move down / up |
| `g` / `G` | Jump to top / bottom |
| `/` | Enter search mode |
| `Esc` | Exit search mode |
| `q` | Quit |
| `Enter` | Attach to session |
| `Ctrl-d` | Attach and detach other clients |
| `r` | Rename selected session |
| `Ctrl-h` | Toggle hide/unhide session |
| `Ctrl-a` | Toggle hidden sessions visibility |
| `Ctrl-x` | Kill session (with confirmation) |

### Creating a new session

Select `[+ ] Create new session`, enter a name, then pick a base directory from
the fzf picker. Press `Esc` to skip and use the current directory.

The directory picker scans `$HOME` (depth 3) and, on macOS, external volumes
under `/Volumes`. On Linux, `/mnt` and `/media` are scanned for external drives.

### Hidden sessions

Press `Ctrl-h` on a session to hide it from the default view. Press `Ctrl-a` to
toggle showing hidden sessions (indented, in a dimmed section). Hidden sessions
are stored in `~/.tmx-hidden-sessions`.

## tmux popup integration

Add to `~/.tmux.conf`:

```tmux
bind-key -T prefix P display-popup -E -w 90% -h 90% -T "tmx" "$HOME/bin/tmx"
```

Then `Prefix + P` opens tmx in a popup.

## License

MIT
